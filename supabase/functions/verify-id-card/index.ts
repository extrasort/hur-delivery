// Supabase Edge Function: ID Card Verification with KYC
// Verifies Iraqi national ID cards using OpenAI GPT-4o Vision
// Detects screen fraud, extracts legal name and ID number

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY')
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey, x-client-info',
}

interface IDVerificationResult {
  success: boolean
  authenticated: boolean
  screen_detected: boolean
  fraud_risk: 'low' | 'medium' | 'high'
  confidence: number
  reason?: string
  legal_name?: {
    first: string
    father: string
    grandfather: string
    family: string
  }
  id_number?: string
  id_expiry_date?: string
  id_birth_date?: string
  card_valid: boolean
  selfie_valid: boolean
  holding_physical_id: boolean
}

const getDocumentVerificationPrompt = (documentType: string) => {
  const documentSpecificInstructions = {
    national_id: `**Document Type:** Iraqi National ID Card
**Text Extraction:**
1. Extract full legal name in Arabic ONLY (4 parts):
   - الاسم (first name) - MUST be in Arabic script
   - الاب (father's name) - MUST be in Arabic script
   - الجد (grandfather's name) - MUST be in Arabic script
   - اللقب (family name/surname) - MUST be in Arabic script
   **CRITICAL: If any name part contains non-Arabic characters (Latin letters, numbers, etc.), REJECT the verification.**
2. Extract ID number from TOP CENTER of card (any format, no restrictions)
3. Extract expiry date from BACK of card (format: YYYY-MM-DD)
4. Extract birth date from BACK of card (format: YYYY-MM-DD)
5. Verify the card appears to be an official Iraqi national ID`,
    
    driver_license: `**Document Type:** Driver License
**Text Extraction:**
1. Extract full legal name (first, father, grandfather, family name)
2. Extract license number (varies by country/format)
3. Extract expiry date (format: YYYY-MM-DD)
4. Extract birth date/date of birth (format: YYYY-MM-DD)
5. Verify the license appears authentic and not expired
6. Check for license categories/types if visible`,
    
    passport: `**Document Type:** Passport
**Text Extraction:**
1. Extract full legal name from identity page (given name + surname)
   - For Arabic passports: extract all 4 name parts if visible
   - For other passports: use given name as first+father, surname as grandfather+family
2. Extract passport number (alphanumeric, varies by country)
3. Extract expiry date from identity page (format: YYYY-MM-DD)
4. Extract birth date/date of birth (format: YYYY-MM-DD)
5. Verify the passport appears authentic and not expired
6. Check nationality field if visible`
  }

  const instructions = documentSpecificInstructions[documentType as keyof typeof documentSpecificInstructions] 
    || documentSpecificInstructions.national_id

  return `You are an expert document verification system with advanced anti-fraud detection. Analyze these images with EXTREME scrutiny.

**CRITICAL SECURITY CHECKS - Screen Detection:**
1. Check if the document is displayed on a digital screen (phone, tablet, monitor, TV)
2. Look for these screen indicators:
   - Screen glare, reflections, or backlight glow
   - Pixel grid or digital display patterns
   - Screen borders, bezels, or frames
   - Unnatural flat appearance without depth
   - Digital UI elements or icons visible
   - Screenshot artifacts or digital compression
3. If ANY screen indicators are found, immediately set "screen_detected": true
4. Real physical documents have: natural shadows, bends, texture, depth, hand holding it

**Driver Selfie Verification (if role is driver):**
1. Person MUST be visibly holding a PHYSICAL document in the selfie
2. The document in the selfie should match the document in the front/back images
3. Check that the document is not displayed on a phone/screen
4. Person's hand should be visible holding the document
5. The document should show depth, shadows, natural lighting
6. If person is NOT holding document, or holding a phone with document image → REJECT

${instructions}`
}

const ID_VERIFICATION_PROMPT_SUFFIX = `

**Fraud Risk Assessment:**
- HIGH: Screen detected, person not holding document, fake/edited images, suspicious artifacts
- MEDIUM: Unclear images, partial information, low quality
- LOW: Clear physical document, person holding it properly, all data visible

**Expected JSON Response:**
{
  "success": true/false,
  "authenticated": true/false,
  "screen_detected": true/false (TRUE if document is on ANY screen),
  "fraud_risk": "low/medium/high",
  "confidence": 0.0-1.0,
  "reason": "explanation if rejected",
  "legal_name": {
    "first": "first name from document",
    "father": "father name (or use part of given name if not available)",
    "grandfather": "grandfather name (or use part of surname if not available)",
    "family": "family name/surname from document"
  },
  "id_number": "document number (format varies by type)",
  "id_expiry_date": "YYYY-MM-DD",
  "id_birth_date": "YYYY-MM-DD",
  "card_valid": true/false,
  "selfie_valid": true/false,
  "holding_physical_id": true/false (for drivers)
}

**STRICT REJECTION CRITERIA:**
- Reject if screen_detected is true
- Reject if fraud_risk is high
- Reject if document number is missing or clearly invalid
- Reject if legal name is incomplete (try to extract at least first and family name)
- Reject if driver selfie does NOT show person holding physical document
- Reject if document appears expired
- Reject if images are too blurry to verify

**Important:**
- Only set "screen_detected": true if you see CLEAR evidence of a digital screen
- Do NOT reject real documents due to normal photo reflections or camera artifacts
- If you see a hand holding the document, natural shadows, or document texture → it's likely physical
- Be strict but fair - the goal is to catch fraud while allowing legitimate users
- For non-Iraqi documents (passports, driver licenses): Be flexible with name format, extract what's available`

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    console.log('🆔 Received ID verification request')

    // Verify OpenAI API key
    if (!OPENAI_API_KEY) {
      console.error('❌ OPENAI_API_KEY not configured')
      return new Response(
        JSON.stringify({ error: 'OpenAI API key not configured' }),
        { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      )
    }

    // Parse form data
    const formData = await req.formData()
    console.log('📋 Form data keys:', Array.from(formData.keys()))

    const idFront = formData.get('id_front') as File
    const idBack = formData.get('id_back') as File
    const selfie = formData.get('selfie') as File
    const userRole = formData.get('role') as string || 'merchant'
    const userId = formData.get('user_id') as string
    const documentType = formData.get('document_type') as string || 'national_id'

    // Validate required images based on document type
    if (!idFront) {
      console.error('❌ Missing required front image')
      return new Response(
        JSON.stringify({ 
          error: 'Missing required front image',
          required: ['id_front'],
          received: Array.from(formData.keys())
        }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      )
    }
    
    // Back image required for national ID and driver license, but NOT for passport
    if (documentType !== 'passport' && !idBack) {
      console.error('❌ Missing required back image')
      return new Response(
        JSON.stringify({ 
          error: 'Missing required back image for this document type',
          required: ['id_front', 'id_back'],
          received: Array.from(formData.keys())
        }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      )
    }

    // Selfie is required only for drivers
    if (userRole === 'driver' && !selfie) {
      console.error('❌ Missing required selfie for driver')
      return new Response(
        JSON.stringify({ 
          error: 'Selfie is required for drivers',
          required: ['id_front', 'id_back', 'selfie'],
          received: Array.from(formData.keys())
        }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      )
    }

    // Log received images
    let logMessage = `📸 Images received - Front: ${idFront.size}B`
    if (idBack) logMessage += `, Back: ${idBack.size}B`
    if (selfie) logMessage += `, Selfie: ${selfie.size}B`
    console.log(logMessage)
    console.log(`👤 User role: ${userRole}, ID: ${userId}`)
    console.log(`📄 Document type: ${documentType}`)

    // Convert images to base64 (using chunked approach to avoid stack overflow)
    const arrayBufferToBase64 = (buffer: ArrayBuffer): string => {
      const bytes = new Uint8Array(buffer)
      let binary = ''
      const chunkSize = 8192 // Process in 8KB chunks to avoid stack overflow
      
      for (let i = 0; i < bytes.length; i += chunkSize) {
        const chunk = bytes.subarray(i, Math.min(i + chunkSize, bytes.length))
        binary += String.fromCharCode.apply(null, Array.from(chunk))
      }
      
      return btoa(binary)
    }

    const frontBuffer = await idFront.arrayBuffer()
    const frontBase64 = arrayBufferToBase64(frontBuffer)
    
    let backBase64: string | null = null
    if (idBack) {
      const backBuffer = await idBack.arrayBuffer()
      backBase64 = arrayBufferToBase64(backBuffer)
    }
    
    let selfieBase64: string | null = null
    if (selfie) {
      const selfieBuffer = await selfie.arrayBuffer()
      selfieBase64 = arrayBufferToBase64(selfieBuffer)
    }

    console.log('🔄 Images converted to base64')
    console.log(`📄 Document type: ${documentType}`)

    // Build prompt based on document type and role
    const basePrompt = getDocumentVerificationPrompt(documentType)
    
    const roleSpecificCheck = userRole === 'driver' 
      ? '\n\n**DRIVER SPECIFIC CHECK:** The selfie MUST show a person holding a PHYSICAL document. The person\'s hand must be visible holding the document. If the document is displayed on a phone screen, or if the person is not holding a physical document, set "holding_physical_id": false and REJECT.'
      : '\n\n**MERCHANT CHECK:** For merchants, selfie validation is optional. Focus on verifying the document authenticity from front and back images only.'

    const finalPrompt = basePrompt + ID_VERIFICATION_PROMPT_SUFFIX + roleSpecificCheck

    // Call OpenAI GPT-4o Vision API
    console.log('🤖 Calling GPT-4o Vision for ID verification...')

    // Build message content array - include images based on document type
    const messageContent: any[] = [
      { type: 'text', text: finalPrompt },
      { type: 'text', text: `\n**Front of ${documentType}:**` },
      { 
        type: 'image_url', 
        image_url: { 
          url: `data:image/jpeg;base64,${frontBase64}`,
          detail: 'high'
        } 
      },
    ]

    // Add back image only if provided (not for passport)
    if (backBase64) {
      messageContent.push(
        { type: 'text', text: `\n**Back of ${documentType}:**` },
        { 
          type: 'image_url', 
          image_url: { 
            url: `data:image/jpeg;base64,${backBase64}`,
            detail: 'high'
          } 
        }
      )
    }

    // Add selfie images only if provided (for drivers)
    if (selfieBase64) {
      messageContent.push(
        { type: 'text', text: '\n**Selfie with document:**' },
        { 
          type: 'image_url', 
          image_url: { 
            url: `data:image/jpeg;base64,${selfieBase64}`,
            detail: 'high'
          } 
        }
      )
    }

    const gptResponse = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o',
        messages: [
          {
            role: 'system',
            content: 'أنت نظام متخصص في التحقق من بطاقات الهوية العراقية. مهمتك اكتشاف الاحتيال ومنع استخدام الصور المعروضة على الشاشات. كن صارماً جداً في فحص الصور.',
          },
          {
            role: 'user',
            content: messageContent,
          },
        ],
        max_tokens: 2000,
        response_format: { type: 'json_object' },
        temperature: 0.1,
      }),
    })

    if (!gptResponse.ok) {
      const error = await gptResponse.text()
      console.error(`❌ GPT-4o Vision error: ${error}`)
      return new Response(
        JSON.stringify({ error: `Verification failed: ${gptResponse.status}` }),
        { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      )
    }

    const gptData = await gptResponse.json()
    const result = JSON.parse(gptData.choices[0].message.content) as IDVerificationResult

    console.log('✅ Verification result:', JSON.stringify(result, null, 2))

    // Validate the result
    if (result.screen_detected) {
      console.warn('🚨 FRAUD ATTEMPT: Screen detected')
      return new Response(
        JSON.stringify({
          success: false,
          authenticated: false,
          reason: 'تم رفض الطلب: يبدو أن بطاقة الهوية معروضة على شاشة. يرجى استخدام بطاقة هوية حقيقية.',
          screen_detected: true,
          fraud_risk: 'high'
        }),
        { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      )
    }

    if (result.fraud_risk === 'high') {
      console.warn('🚨 FRAUD ATTEMPT: High risk detected')
      return new Response(
        JSON.stringify({
          success: false,
          authenticated: false,
          reason: 'تم رفض الطلب: مخاطر أمنية عالية. يرجى التأكد من استخدام صور واضحة لبطاقة هوية حقيقية.',
          fraud_risk: 'high'
        }),
        { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      )
    }

    // For drivers, check if holding physical ID
    if (userRole === 'driver' && !result.holding_physical_id) {
      console.warn('🚨 Driver not holding physical ID')
      return new Response(
        JSON.stringify({
          success: false,
          authenticated: false,
          reason: 'يرجى التقاط صورة شخصية وأنت تحمل بطاقة الهوية الحقيقية بيدك.',
          holding_physical_id: false
        }),
        { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      )
    }

    // Validate ID/document number (format depends on document type)
    if (!result.id_number || result.id_number.trim().length === 0) {
      console.error('❌ Missing document number')
      return new Response(
        JSON.stringify({
          success: false,
          authenticated: false,
          reason: 'لم يتم التعرف على رقم الوثيقة بشكل صحيح. يرجى التأكد من وضوح الصورة.',
          id_number_invalid: true
        }),
        { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      )
    }
    
    // No format validation - accept any ID number format
    // Just ensure it's not empty

    // Validate legal name is complete (all 4 parts) and in Arabic
    if (!result.legal_name || 
        !result.legal_name.first || 
        !result.legal_name.father || 
        !result.legal_name.grandfather || 
        !result.legal_name.family) {
      console.error('❌ Incomplete legal name')
      return new Response(
        JSON.stringify({
          success: false,
          authenticated: false,
          reason: 'لم يتم التعرف على الاسم الكامل من بطاقة الهوية. يرجى التأكد من وضوح الصورة.',
          name_incomplete: true
        }),
        { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      )
    }

    // Validate that all name parts are in Arabic script
    const arabicRegex = /^[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF\s]+$/
    const nameParts = [
      result.legal_name.first,
      result.legal_name.father,
      result.legal_name.grandfather,
      result.legal_name.family
    ]
    
    for (const part of nameParts) {
      if (!arabicRegex.test(part)) {
        console.error('❌ Name contains non-Arabic characters:', part)
        return new Response(
          JSON.stringify({
            success: false,
            authenticated: false,
            reason: 'يجب أن يكون الاسم باللغة العربية فقط. يرجى التأكد من أن بطاقة الهوية تحتوي على اسم بالعربية.',
            name_not_arabic: true
          }),
          { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
        )
      }
    }

    // If userId is provided, update the database
    if (userId) {
      try {
        const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

        // Call the database function to update user verification
        const { data, error } = await supabase.rpc('update_user_id_verification', {
          p_user_id: userId,
          p_id_number: result.id_number,
          p_legal_first_name: result.legal_name.first,
          p_legal_father_name: result.legal_name.father,
          p_legal_grandfather_name: result.legal_name.grandfather,
          p_legal_family_name: result.legal_name.family,
          p_id_front_url: `id_cards/${userId}/front.jpg`, // Will be uploaded separately
          p_id_back_url: `id_cards/${userId}/back.jpg`,
          p_selfie_url: `id_cards/${userId}/selfie.jpg`,
          p_id_expiry_date: result.id_expiry_date || null,
          p_id_birth_date: result.id_birth_date || null,
          p_verification_notes: result.reason || 'Verified via AI'
        })

        if (error) {
          console.error('❌ Database update error:', error)
          
          // Check if it's a duplicate ID number error
          if (error.message.includes('مسجل بالفعل') || error.message.includes('unique')) {
            return new Response(
              JSON.stringify({
                success: false,
                authenticated: false,
                reason: 'هذا الرقم الوطني مسجل بالفعل في النظام. لا يمكن استخدام نفس الهوية لأكثر من حساب.',
                duplicate_id: true
              }),
              { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
            )
          }

          throw error
        }

        console.log('✅ User verification updated in database')
      } catch (dbError) {
        console.error('❌ Database error:', dbError)
        return new Response(
          JSON.stringify({
            success: false,
            error: 'Database update failed',
            details: dbError.toString()
          }),
          { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
        )
      }
    }

    // Return successful verification
    const response: IDVerificationResult = {
      success: true,
      authenticated: result.authenticated,
      screen_detected: false,
      fraud_risk: result.fraud_risk || 'low',
      confidence: result.confidence,
      legal_name: result.legal_name,
      id_number: result.id_number,
      id_expiry_date: result.id_expiry_date,
      id_birth_date: result.id_birth_date,
      card_valid: result.card_valid,
      selfie_valid: selfieBase64 ? result.selfie_valid : true, // Optional for merchants
      holding_physical_id: userRole === 'driver' ? result.holding_physical_id : true,
    }

    console.log('✅ ID verification complete:', response)

    return new Response(JSON.stringify(response), {
      headers: {
        'Content-Type': 'application/json',
        ...corsHeaders,
      },
    })

  } catch (error) {
    console.error('❌ Error:', error)
    console.error('❌ Error stack:', error.stack)
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Verification failed',
        details: error.toString(),
      }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders,
        },
      }
    )
  }
})

