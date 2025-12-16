// Monitor Pending Orders - Supabase Edge Function
// This function checks for pending orders that need assignment or reassignment
// Should be called every second via pg_cron or external scheduler

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase client with service role key
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    
    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY')
    }
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    })

    console.log('[monitor-pending-orders] Starting check...')

    const now = new Date().toISOString()

    // Use RPC function to check and process pending orders
    // This function handles all the logic in the database
    const { data: results, error: rpcError } = await supabase.rpc(
      'check_and_assign_pending_orders'
    )

    if (rpcError) {
      console.error('[monitor-pending-orders] RPC error:', rpcError)
      
      // If RPC function doesn't exist, fall back to edge function logic
      if (rpcError.message.includes('function') && rpcError.message.includes('does not exist')) {
        console.log('[monitor-pending-orders] RPC function not found, using fallback logic')
        
        // Get all pending orders
        const { data: allPendingOrders, error: fetchError } = await supabase
          .from('orders')
          .select('id, created_at, driver_id, driver_assigned_at, status, pickup_latitude, pickup_longitude, vehicle_type')
          .eq('status', 'pending')

        if (fetchError) {
          throw fetchError
        }

        if (!allPendingOrders || allPendingOrders.length === 0) {
          return new Response(
            JSON.stringify({
              success: true,
              checked: 0,
              assigned: 0,
              rejected: 0,
              timestamp: now,
              message: 'No orders need attention'
            }),
            {
              headers: { ...corsHeaders, 'Content-Type': 'application/json' },
              status: 200,
            }
          )
        }

        // Filter orders that need attention (30 seconds threshold)
        const pendingOrders = allPendingOrders.filter((order: any) => {
          const orderCreatedAt = new Date(order.created_at)
          const orderAssignedAt = order.driver_assigned_at ? new Date(order.driver_assigned_at) : null
          const nowDate = new Date()
          
          const timeSinceCreated = (nowDate.getTime() - orderCreatedAt.getTime()) / 1000
          const timeSinceAssigned = orderAssignedAt 
            ? (nowDate.getTime() - orderAssignedAt.getTime()) / 1000 
            : null

          // Orders created >= 30 seconds ago with no driver
          const needsAssignment = !order.driver_id && timeSinceCreated >= 30
          // Orders with driver_assigned_at >= 30 seconds ago
          const needsReassignment = order.driver_id && orderAssignedAt && timeSinceAssigned && timeSinceAssigned >= 30

          return needsAssignment || needsReassignment
        })

        if (pendingOrders.length === 0) {
          return new Response(
            JSON.stringify({
              success: true,
              checked: allPendingOrders.length,
              assigned: 0,
              rejected: 0,
              timestamp: now,
              message: 'No orders need attention'
            }),
            {
              headers: { ...corsHeaders, 'Content-Type': 'application/json' },
              status: 200,
            }
          )
        }

        console.log(`[monitor-pending-orders] Found ${pendingOrders.length} orders to process (fallback mode)`)

        let assignedCount = 0
        let rejectedCount = 0
        const fallbackResults = []

        // Process each order
        for (const order of pendingOrders) {
          try {
            // If order has a driver assigned but hasn't accepted (30 seconds passed)
            if (order.driver_id && order.driver_assigned_at) {
              const orderAssignedAt = new Date(order.driver_assigned_at)
              const timeSinceAssigned = (Date.now() - orderAssignedAt.getTime()) / 1000
              
              if (timeSinceAssigned >= 30) {
                // Remove the current driver assignment
                const { error: removeError } = await supabase
                  .from('orders')
                  .update({
                    driver_id: null,
                    driver_assigned_at: null,
                    updated_at: now
                  })
                  .eq('id', order.id)
                  .eq('status', 'pending')

                if (!removeError) {
                  // Add driver to rejected list
                  await supabase
                    .from('order_rejected_drivers')
                    .insert({
                      order_id: order.id,
                      driver_id: order.driver_id,
                      reason: 'timeout'
                    })
                    .select()
                    .single()

                  console.log(`[monitor-pending-orders] Removed timed-out driver ${order.driver_id} from order ${order.id}`)
                }
              }
            }

            // Try to assign next available driver
            const { data: assignResult, error: assignError } = await supabase.rpc(
              'auto_assign_order',
              { p_order_id: order.id }
            )

            if (assignError) {
              console.error(`[monitor-pending-orders] Error assigning order ${order.id}:`, assignError)
              fallbackResults.push({
                order_id: order.id,
                status: 'error',
                error: assignError.message
              })
              continue
            }

            if (assignResult === true) {
              assignedCount++
              fallbackResults.push({
                order_id: order.id,
                status: 'assigned',
                message: 'Order assigned to new driver'
              })
              console.log(`[monitor-pending-orders] Successfully assigned order ${order.id}`)
            } else {
              // Check if order was marked as rejected
              const { data: orderCheck } = await supabase
                .from('orders')
                .select('status')
                .eq('id', order.id)
                .single()

              if (orderCheck?.status === 'rejected') {
                rejectedCount++
                fallbackResults.push({
                  order_id: order.id,
                  status: 'rejected',
                  message: 'No available drivers - order rejected'
                })
                console.log(`[monitor-pending-orders] Order ${order.id} marked as rejected (no drivers available)`)
              } else {
                fallbackResults.push({
                  order_id: order.id,
                  status: 'pending',
                  message: 'Still pending - will retry on next check'
                })
              }
            }

          } catch (orderError) {
            console.error(`[monitor-pending-orders] Error processing order ${order.id}:`, orderError)
            fallbackResults.push({
              order_id: order.id,
              status: 'error',
              error: orderError.message
            })
          }
        }

        return new Response(
          JSON.stringify({
            success: true,
            checked: pendingOrders.length,
            assigned: assignedCount,
            rejected: rejectedCount,
            results: fallbackResults,
            timestamp: now,
            message: `Processed ${pendingOrders.length} orders: ${assignedCount} assigned, ${rejectedCount} rejected (fallback mode)`
          }),
          {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
          }
        )
      }
      
      throw rpcError
    }

    // Process results from RPC function
    if (!results || results.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          checked: 0,
          assigned: 0,
          rejected: 0,
          timestamp: now,
          message: 'No orders need attention'
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        }
      )
    }

    const assigned = results.filter((r: any) => r.action_taken === 'assigned').length
    const rejected = results.filter((r: any) => r.action_taken === 'rejected').length

    console.log(`[monitor-pending-orders] Completed: ${assigned} assigned, ${rejected} rejected`)

    return new Response(
      JSON.stringify({
        success: true,
        checked: results.length,
        assigned,
        rejected,
        results,
        timestamp: now,
        message: `Processed ${results.length} orders: ${assigned} assigned, ${rejected} rejected`
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    console.error('[monitor-pending-orders] Fatal error:', error)
    
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
        timestamp: new Date().toISOString()
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})
