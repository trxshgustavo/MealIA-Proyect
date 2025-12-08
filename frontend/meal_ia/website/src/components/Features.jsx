import { FaCamera, FaBrain, FaLeaf } from 'react-icons/fa';

const Features = () => {
    const features = [
        {
            icon: <FaCamera />,
            title: 'Instant Scan',
            desc: 'Snap a photo. We recognize ingredients instantly.',
            color: '#FF6B6B'
        },
        {
            icon: <FaBrain />,
            title: 'AI Chef',
            desc: 'Creative recipes tailored to what you have.',
            color: '#4ECDC4'
        },
        {
            icon: <FaLeaf />,
            title: 'Eco Friendly',
            desc: 'Stop throwing away food. Save the planet.',
            color: '#FFE66D'
        }
    ];

    const styles = {
        section: {
            padding: '6rem 5%',
            background: 'var(--white)',
        },
        container: {
            maxWidth: 'var(--max-width)',
            margin: '0 auto',
        },
        grid: {
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))',
            gap: '3rem',
        },
        card: {
            background: 'var(--light)',
            padding: '2.5rem',
            borderRadius: '20px',
            textAlign: 'left',
            transition: 'all 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275)',
            border: '2px solid transparent',
            cursor: 'default',
        },
        iconWrapper: {
            width: '60px',
            height: '60px',
            borderRadius: '15px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: '1.8rem',
            color: 'white',
            marginBottom: '1.5rem',
            boxShadow: '0 10px 20px rgba(0,0,0,0.1)',
        },
        title: {
            fontSize: '1.5rem',
            fontWeight: '800',
            marginBottom: '0.8rem',
            color: 'var(--dark)',
        },
        desc: {
            color: 'var(--text-muted)',
            lineHeight: '1.6',
        }
    };

    return (
        <div id="features" style={styles.section}>
            <div style={styles.container}>
                <div style={styles.grid}>
                    {features.map((f, i) => (
                        <div
                            key={i}
                            style={styles.card}
                            onMouseOver={(e) => {
                                e.currentTarget.style.transform = 'translateY(-10px)';
                                e.currentTarget.style.boxShadow = '0 20px 40px rgba(0,0,0,0.1)';
                                e.currentTarget.style.borderColor = f.color;
                            }}
                            onMouseOut={(e) => {
                                e.currentTarget.style.transform = 'translateY(0)';
                                e.currentTarget.style.boxShadow = 'none';
                                e.currentTarget.style.borderColor = 'transparent';
                            }}
                        >
                            <div style={{ ...styles.iconWrapper, background: f.color }}>
                                {f.icon}
                            </div>
                            <h3 style={styles.title}>{f.title}</h3>
                            <p style={styles.desc}>{f.desc}</p>
                        </div>
                    ))}
                </div>
            </div>
        </div>
    );
};

export default Features;
