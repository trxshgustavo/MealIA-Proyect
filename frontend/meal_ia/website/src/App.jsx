import { useState } from 'react';
import Navbar from './components/Navbar';
import Hero from './components/Hero';
import Features from './components/Features';
import FAQ from './components/FAQ';
import Footer from './components/Footer';
import LoginModal from './components/LoginModal';
import './App.css';

function App() {
  const [isLoginOpen, setIsLoginOpen] = useState(false);

  // App container styles not really needed if body handles bg, 
  // but lets ensure full width/overflow control
  const styles = {
    app: {
      width: '100%',
      overflowX: 'hidden',
      background: 'var(--light)', /* Fallback/Base */
    }
  };

  return (
    <div style={styles.app}>
      <Navbar onLoginClick={() => setIsLoginOpen(true)} />
      <Hero />
      <Features />
      <FAQ />
      <Footer />
      {isLoginOpen && <LoginModal onClose={() => setIsLoginOpen(false)} />}
    </div>
  );
}

export default App;
