const QUICK = [
    { label: 'Supply — private', msg: "N. Naz Block N mein 400gz plot hai, 50 ki line, demand 4.2cr. Private rakho." },
    { label: 'Supply — public', msg: "Block N mein 400gz corner plot, 45 ki line, demand 3.9cr. Public karo." },
    { label: 'Demand — Block N', msg: "Mujhe Block N mein 400gz plot chahiye, budget 4cr. Corner ho toh acha." },
    { label: 'Demand — Gulshan', msg: "Gulshan Block 13 mein 240gz west open plot chahiye, budget 3.2cr." },
    { label: 'Filler words test', msg: "Bhai sun, duaon mein yaad rakhna. Block N mein 400gz corner, 3.85cr. Public karo." },
    { label: 'Duplicate trigger', msg: "North Nazimabad Block N mein 400gz plot, demand 3.9cr. Public." },
]

export default function QuickMessages({ onSelect }) {
    return (
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px', marginTop: '10px' }}>
            {QUICK.map(q => (
                <button
                    key={q.label}
                    onClick={() => onSelect(q.msg)}
                    style={{
                        background: 'var(--surface2)',
                        border: '1px solid var(--border)',
                        borderRadius: '20px',
                        padding: '3px 10px',
                        fontSize: '11px',
                        color: 'var(--muted)',
                        cursor: 'pointer',
                        fontFamily: 'var(--font-sans)',
                        transition: 'all .15s',
                    }}
                    onMouseEnter={e => {
                        e.target.style.color = 'var(--text)'
                        e.target.style.borderColor = 'var(--border-hi)'
                    }}
                    onMouseLeave={e => {
                        e.target.style.color = 'var(--muted)'
                        e.target.style.borderColor = 'var(--border)'
                    }}
                >
                    {q.label}
                </button>
            ))}
        </div>
    )
}