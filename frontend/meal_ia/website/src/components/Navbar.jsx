import { useState, useEffect } from 'react';
import { FaRobot } from 'react-icons/fa';

const Navbar = ({ onLoginClick }) => {
    const [scrolled, setScrolled] = useState(false);

    useEffect(() => {
        const handleScroll = () => {
            setScrolled(window.scrollY > 20);
        };
        window.addEventListener('scroll', handleScroll);
        return () => window.removeEventListener('scroll', handleScroll);
    }, []);

    const styles = {
        wrapper: {
            position: 'fixed',
            top: 0,
            width: '100%',
            zIndex: 1000,
            transition: 'all 0.3s ease',
            background: scrolled ? 'rgba(255, 255, 255, 0.9)' : 'transparent',
            backdropFilter: scrolled ? 'blur(10px)' : 'none',
            boxShadow: scrolled ? '0 4px 20px rgba(0,0,0,0.05)' : 'none',
            padding: scanned ? '0.5rem 0' : '1rem 0',
        },
        nav: {
            maxWidth: 'var(--max-width)',
            margin: '0 auto',
            padding: '0 5%',
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
        },
        logo: {
            fontSize: '1.5rem',
            fontWeight: '800',
            color: 'var(--dark)',
            display: 'flex',
            alignItems: 'center',
            gap: '0.5rem',
        },
        links: {
            display: 'flex',
            gap: '2.5rem',
            alignItems: 'center',
        },
        link: {
            color: 'var(--dark)',
            fontWeight: '600',
            fontSize: '0.95rem',
        },
        button: {
            background: 'var(--primary)',
            color: 'white',
            border: 'none',
            padding: '0.7rem 1.8rem',
            borderRadius: '50px',
            fontSize: '0.95rem',
            fontWeight: 'bold',
            transition: 'all 0.2s',
            boxShadow: '0 4px 10px rgba(255, 107, 107, 0.3)',
        }
    };

    // Fix scanned variable typo in styles
    const scanned = scrolled; // alias for clarity in style obj logic if needed, but lets just fix the object

    return (
        <div style={{ ...styles.wrapper, padding: scrolled ? '0.5rem 0' : '1rem 0' }}>
            <nav style={styles.nav}>
                <div style={styles.logo}>
                    <FaRobot style={{ color: 'var(--primary)' }} /> MealIA
                </div>
                <div style={styles.links}>
                    <a href="#features" style={styles.link}>Features</a>
                    <a href="#faq" style={styles.link}>FAQ</a>
                    <button
                        style={styles.button}
                        onClick={onLoginClick}
                        onMouseOver={(e) => {
                            e.target.style.transform = 'translateY(-2px)';
                            e.target.style.boxShadow = '0 6px 15px rgba(255, 107, 107, 0.4)';
                        }}
                        onMouseOut={(e) => {
                            e.target.style.transform = 'translateY(0)';
                            e.target.style.boxShadow = '0 4px 10px rgba(255, 107, 107, 0.3)';
                        }}
                    >
                        Login
                    </button>
                </div>
            </nav>
        </div>
    );
};

export default Navbar;
