import { FaTwitter, FaInstagram, FaGithub, FaLinkedin } from 'react-icons/fa';

const Footer = () => {
    const styles = {
        footer: {
            padding: '5rem 5%',
            textAlign: 'center',
            background: 'white',
            borderTop: '1px solid #f0f0f0',
        },
        container: {
            maxWidth: 'var(--max-width)',
            margin: '0 auto',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
        },
        brand: {
            color: 'var(--primary)',
            fontWeight: '900',
            fontSize: '1.5rem',
            marginBottom: '2rem',
            letterSpacing: '-0.5px',
        },
        socials: {
            display: 'flex',
            justifyContent: 'center',
            gap: '2.5rem',
            marginBottom: '2.5rem',
            fontSize: '1.4rem',
        },
        icon: {
            color: '#cbd5e0',
            cursor: 'pointer',
            transition: 'all 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275)',
        },
        copy: {
            fontSize: '0.9rem',
            color: 'var(--text-muted)',
        }
    };

    const handleHover = (e, color) => {
        e.target.style.color = color;
        e.target.style.transform = 'translateY(-5px)';
    };

    const handleOut = (e) => {
        e.target.style.color = '#cbd5e0';
        e.target.style.transform = 'translateY(0)';
    };

    return (
        <footer style={styles.footer}>
            <div style={styles.container}>
                <div style={styles.brand}>MealIA</div>
                <div style={styles.socials}>
                    <FaTwitter style={styles.icon} onMouseOver={(e) => handleHover(e, '#1DA1F2')} onMouseOut={handleOut} />
                    <FaInstagram style={styles.icon} onMouseOver={(e) => handleHover(e, '#E1306C')} onMouseOut={handleOut} />
                    <FaGithub style={styles.icon} onMouseOver={(e) => handleHover(e, '#333')} onMouseOut={handleOut} />
                    <FaLinkedin style={styles.icon} onMouseOver={(e) => handleHover(e, '#0077b5')} onMouseOut={handleOut} />
                </div>
                <p style={styles.copy}>© 2025 MealIA. All rights reserved.</p>
            </div>
        </footer>
    );
};

export default Footer;
