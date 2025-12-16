import { motion } from 'framer-motion';
import '../styles/ParticlesBackground.css';

const ParticlesBackground = () => {
  const particles = Array.from({ length: 30 });

  return (
    <div className="particles-container">
      {particles.map((_, index) => (
        <motion.div
          key={index}
          className="particle"
          initial={{
            x: Math.random() * window.innerWidth,
            y: Math.random() * window.innerHeight,
            opacity: Math.random() * 0.5 + 0.2,
            scale: Math.random() * 0.5 + 0.5,
          }}
          animate={{
            y: [null, Math.random() * window.innerHeight],
            x: [null, Math.random() * window.innerWidth],
          }}
          transition={{
            duration: Math.random() * 20 + 20,
            repeat: Infinity,
            repeatType: 'reverse',
            ease: 'linear',
          }}
        />
      ))}
    </div>
  );
};

export default ParticlesBackground;



