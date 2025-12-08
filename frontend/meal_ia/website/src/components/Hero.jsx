const Hero = () => {
    const styles = {
        section: {
            minHeight: '90vh',
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'center',
            alignItems: 'center',
            textAlign: 'center',
            padding: '0 5%',
            position: 'relative',
            background: 'radial-gradient(circle at 50% 50%, #ffffff 0%, #f0f4f8 100%)',
            overflow: 'hidden',
        },
        blob1: {
            position: 'absolute',
            top: '-10%',
            left: '-10%',
            width: '500px',
            height: '500px',
            background: 'var(--secondary)',
            opacity: 0.1,
            borderRadius: '50%',
            filter: 'blur(80px)',
            zIndex: 0,
        },
        blob2: {
            position: 'absolute',
            bottom: '10%',
            right: '-5%',
            width: '400px',
            height: '400px',
            background: 'var(--primary)',
            opacity: 0.1,
            borderRadius: '50%',
            filter: 'blur(80px)',
            zIndex: 0,
        },
        content: {
            zIndex: 1,
            maxWidth: '900px',
        },
        title: {
            fontSize: '4rem',
            fontWeight: '800',
            color: 'var(--dark)',
            marginBottom: '1.5rem',
            lineHeight: 1.1,
            opacity: 0, /* for animation */
            animation: 'fadeInUp 0.8s ease-out forwards',
        },
        highlight: {
            color: 'var(--primary)',
            position: 'relative',
            display: 'inline-block',
        },
        subtitle: {
            fontSize: '1.3rem',
            color: 'var(--text-muted)',
            marginBottom: '3rem',
            maxWidth: '650px',
            marginLeft: 'auto',
            marginRight: 'auto',
            opacity: 0,
            animation: 'fadeInUp 0.8s ease-out 0.2s forwards',
        },
        cta: {
            background: 'var(--dark)',
            color: 'white',
            padding: '1rem 3rem',
            borderRadius: '50px',
            fontSize: '1.1rem',
            fontWeight: '600',
            border: 'none',
            cursor: 'pointer',
            boxShadow: '0 10px 20px rgba(44, 62, 80, 0.2)',
            transition: 'all 0.3s ease',
            opacity: 0,
            animation: 'popIn 0.5s cubic-bezier(0.175, 0.885, 0.32, 1.275) 0.4s forwards',
        },
        imageContainer: {
            marginTop: '3rem',
            animation: 'float 6s ease-in-out infinite',
            opacity: 0,
            animationName: 'float, fadeInUp', /* multiple animations need careful syntax, let's just do fade in then float via css class wrapper */
            animationDuration: '6s, 1s',
            animationDelay: '0s, 0.6s',
            animationFillMode: 'none, forwards',
            // actually easier to split wrapper
        },
        emoji: {
            fontSize: '4rem',
            margin: '0 2rem',
            display: 'inline-block',
        }
    };

    return (
        <div style={styles.section}>
            <div style={{ ...styles.blob1, animation: 'float 10s infinite reverse' }}></div>
            <div style={{ ...styles.blob2, animation: 'float 8s infinite' }}></div>

            <div style={styles.content}>
                <h1 style={styles.title}>
                    Cook Smarter,<br />
                    Eat <span style={styles.highlight}>Better</span>.
                </h1>
                <p style={styles.subtitle}>
                    The AI-powered kitchen assistant that turns your messy pantry into delicious meals. Zero waste, zero stress.
                </p>
                <button
                    style={styles.cta}
                    onMouseOver={(e) => {
                        e.target.style.transform = 'translateY(-5px) scale(1.05)';
                        e.target.style.boxShadow = '0 15px 30px rgba(44, 62, 80, 0.3)';
                    }}
                    onMouseOut={(e) => {
                        e.target.style.transform = 'translateY(0) scale(1)';
                        e.target.style.boxShadow = '0 10px 20px rgba(44, 62, 80, 0.2)';
                    }}
                >
                    Start Your Journey
                </button>

                <div style={{ marginTop: '4rem', opacity: 0, animation: 'fadeInUp 1s ease-out 0.6s forwards' }}>
                    <div className="animate-float">
                        <span style={styles.emoji}>🥑</span>
                        <span style={styles.emoji}>🤖</span>
                        <span style={styles.emoji}>🥗</span>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default Hero;
