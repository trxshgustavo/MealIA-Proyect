import { FaTimes, FaGoogle, FaEnvelope } from 'react-icons/fa';

const LoginModal = ({ onClose }) => {
    const styles = {
        overlay: {
            position: 'fixed',
            top: 0,
            left: 0,
            width: '100%',
            height: '100%',
            background: 'rgba(255, 255, 255, 0.8)',
            backdropFilter: 'blur(5px)',
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'center',
            zIndex: 2000,
            animation: 'fadeIn 0.3s ease',
        },
        modal: {
            background: 'white',
            padding: '3rem',
            borderRadius: '24px',
            width: '90%',
            maxWidth: '420px',
            position: 'relative',
            boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.15)',
            border: '1px solid #f0f0f0',
            animation: 'popIn 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275)',
        },
        close: {
            position: 'absolute',
            top: '1.5rem',
            right: '1.5rem',
            background: '#f7f9fc',
            border: 'none',
            color: 'var(--text-muted)',
            fontSize: '1rem',
            cursor: 'pointer',
            padding: '0.5rem',
            borderRadius: '50%',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            transition: 'all 0.2s',
        },
        title: {
            textAlign: 'center',
            fontSize: '1.8rem',
            fontWeight: '800',
            marginBottom: '0.5rem',
            color: 'var(--dark)',
        },
        subtitle: {
            textAlign: 'center',
            color: 'var(--text-muted)',
            marginBottom: '2.5rem',
        },
        btn: {
            width: '100%',
            padding: '1rem',
            marginBottom: '1rem',
            borderRadius: '12px',
            border: 'none',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '1rem',
            fontSize: '1rem',
            fontWeight: '600',
            cursor: 'pointer',
            transition: 'transform 0.2s, box-shadow 0.2s',
        },
        google: {
            background: 'white',
            color: '#333',
            border: '2px solid #f0f0f0',
        },
        email: {
            background: 'var(--primary)',
            color: 'white',
            boxShadow: '0 4px 10px rgba(255, 107, 107, 0.2)',
        }
    };

    return (
        <div style={styles.overlay} onClick={onClose}>
            <div style={styles.modal} onClick={e => e.stopPropagation()}>
                <button
                    style={styles.close}
                    onClick={onClose}
                    onMouseOver={e => { e.target.style.background = '#ffe5e5'; e.target.style.color = 'var(--primary)' }}
                    onMouseOut={e => { e.target.style.background = '#f7f9fc'; e.target.style.color = 'var(--text-muted)' }}
                >
                    <FaTimes />
                </button>

                <h2 style={styles.title}>Welcome Back</h2>
                <p style={styles.subtitle}>Log in to access your meal plans</p>

                <button
                    style={{ ...styles.btn, ...styles.google }}
                    onMouseOver={e => e.currentTarget.style.transform = 'translateY(-2px)'}
                    onMouseOut={e => e.currentTarget.style.transform = 'translateY(0)'}
                >
                    <FaGoogle /> Continue with Google
                </button>

                <button
                    style={{ ...styles.btn, ...styles.email }}
                    onMouseOver={e => {
                        e.currentTarget.style.transform = 'translateY(-2px)';
                        e.currentTarget.style.boxShadow = '0 8px 20px rgba(255, 107, 107, 0.3)';
                    }}
                    onMouseOut={e => {
                        e.currentTarget.style.transform = 'translateY(0)';
                        e.currentTarget.style.boxShadow = '0 4px 10px rgba(255, 107, 107, 0.2)';
                    }}
                >
                    <FaEnvelope /> Continue with Email
                </button>

                <p style={{ textAlign: 'center', marginTop: '2rem', color: '#888', fontSize: '0.9rem' }}>
                    Don't have an account? <span style={{ color: 'var(--primary)', fontWeight: 'bold', cursor: 'pointer' }}>Sign up</span>
                </p>
            </div>
        </div>
    );
};

export default LoginModal;
