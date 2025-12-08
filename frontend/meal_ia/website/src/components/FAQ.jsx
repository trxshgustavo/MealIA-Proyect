import { useState } from 'react';
import { FaChevronDown, FaChevronUp } from 'react-icons/fa';

const FAQ = () => {
    const [openIndex, setOpenIndex] = useState(null);

    const questions = [
        {
            q: "How does the AI scanning work?",
            a: "We use advanced computer vision models to recognize thousands of ingredients from a single photo of your fridge or pantry."
        },
        {
            q: "Is the app free to use?",
            a: "MealIA offers a generous free tier. Premium features like advanced macro tracking require a subscription."
        },
        {
            q: "Can I input dietary restrictions?",
            a: "Absolutely! You can filter recipes for Vegan, Keto, Gluten-Free, and many other dietary needs."
        }
    ];

    const toggle = (i) => setOpenIndex(openIndex === i ? null : i);

    const styles = {
        section: {
            padding: '6rem 5%',
            maxWidth: '800px',
            margin: '0 auto',
        },
        header: {
            textAlign: 'center',
            fontSize: '2.5rem',
            fontWeight: '800',
            marginBottom: '4rem',
            color: 'var(--dark)',
        },
        item: {
            marginBottom: '1.5rem',
            background: 'white',
            borderRadius: '16px',
            boxShadow: '0 4px 6px rgba(0,0,0,0.02)',
            transition: 'box-shadow 0.3s ease',
            border: '1px solid #f0f0f0',
            overflow: 'hidden',
        },
        question: {
            padding: '1.5rem 2rem',
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            cursor: 'pointer',
            fontWeight: 'bold',
            fontSize: '1.1rem',
            color: 'var(--dark)',
            transition: 'color 0.2s',
        },
        answer: {
            padding: '0 2rem 1.5rem',
            color: 'var(--text-muted)',
            lineHeight: '1.6',
            borderTop: '1px solid #f7f9fc',
            marginTop: '-0.5rem',
            paddingTop: '1rem',
        }
    };

    return (
        <div id="faq" style={styles.section}>
            <h2 style={styles.header}>Common Questions</h2>
            {questions.map((q, i) => (
                <div
                    key={i}
                    style={styles.item}
                    onMouseOver={(e) => e.currentTarget.style.boxShadow = '0 10px 20px rgba(0,0,0,0.05)'}
                    onMouseOut={(e) => e.currentTarget.style.boxShadow = '0 4px 6px rgba(0,0,0,0.02)'}
                >
                    <div style={styles.question} onClick={() => toggle(i)}>
                        {q.q}
                        {openIndex === i ? <FaChevronUp style={{ color: 'var(--primary)' }} /> : <FaChevronDown style={{ color: '#cbd5e0' }} />}
                    </div>
                    {openIndex === i && (
                        <div style={styles.answer}>
                            {q.a}
                        </div>
                    )}
                </div>
            ))}
        </div>
    );
};

export default FAQ;
