import { useEffect, useRef } from 'react'

const AGENT_META = {
    Gatekeeper: { icon: '🔍', accent: '#a78bfa' },
    Negotiator: { icon: '⚖️', accent: '#f59e0b' },
    Matchmaker: { icon: '🔗', accent: '#4ade80' },
    Orchestrator: { icon: '🚀', accent: '#60a5fa' },
    Janitor: { icon: '🧹', accent: '#9ca3af' },
    Recommender: { icon: '💡', accent: '#f59e0b' },
}

const STEP_LABELS = {
    parsing: 'Parsing message...',
    parsed: 'Parsed ✓',
    saving_listing: 'Saving listing...',
    saving_demand: 'Saving demand...',
    duplicate_check: 'Checking duplicates...',
    immediate_match: 'Matching listings...',
    scanning_requests: 'Scanning requests...',
    awaiting_confirm: 'Awaiting confirm...',
    complete: 'Complete ✓',
    start: 'Starting...',
}

export default function AgentCard({ name, logs }) {
    const meta = AGENT_META[name] || { icon: '🤖', accent: '#6b7280' }
    const myLogs = logs.filter(l => l.agent_name === name)
    const latest = myLogs[myLogs.length - 1]
    const status = latest?.status || 'idle'
    const step = latest?.step || ''
    const cardRef = useRef(null)

    useEffect(() => {
        if (!cardRef.current) return
        if (status === 'running') {
            cardRef.current.style.boxShadow = `0 0 0 1.5px ${meta.accent}44, 0 0 20px ${meta.accent}18`
            cardRef.current.style.borderColor = `${meta.accent}55`
        } else if (status === 'done') {
            cardRef.current.style.boxShadow = `0 0 0 1.5px ${meta.accent}66`
            cardRef.current.style.borderColor = `${meta.accent}55`
        } else {
            cardRef.current.style.boxShadow = 'none'
            cardRef.current.style.borderColor = 'var(--border)'
        }
    }, [status, meta.accent])

    return (
        <div ref={cardRef} style={{
            background: 'var(--surface)',
            border: '1px solid var(--border)',
            borderRadius: 'var(--r)',
            padding: '1rem',
            transition: 'box-shadow .35s, border-color .35s',
            position: 'relative',
            overflow: 'hidden',
        }}>
            {status === 'running' && (
                <div style={{
                    position: 'absolute',
                    top: 0, left: 0, right: 0,
                    height: '2px',
                    background: `linear-gradient(90deg, transparent, ${meta.accent}, transparent)`,
                    animation: 'slide 1.4s linear infinite',
                }} />
            )}

            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '10px' }}>
                <div style={{
                    width: '36px', height: '36px', borderRadius: '8px',
                    background: `${meta.accent}18`,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontSize: '18px', flexShrink: 0,
                }}>
                    {meta.icon}
                </div>
                <div>
                    <div style={{ fontWeight: 500, fontSize: '13px' }}>{name}</div>
                    <div style={{ fontSize: '11px', color: 'var(--muted)', fontFamily: 'var(--font-mono)', marginTop: '1px' }}>
                        {STEP_LABELS[step] || (step || 'waiting...')}
                    </div>
                </div>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                {status === 'running' && (
                    <div style={{
                        width: '7px', height: '7px', borderRadius: '50%',
                        background: meta.accent,
                        animation: 'blink 1s ease-in-out infinite',
                        flexShrink: 0,
                    }} />
                )}
                <span style={{
                    fontSize: '10px',
                    fontFamily: 'var(--font-mono)',
                    padding: '2px 8px',
                    borderRadius: '20px',
                    background: status === 'running' ? `${meta.accent}18`
                        : status === 'done' ? 'var(--accent-dim)'
                            : status === 'error' ? 'var(--err-dim)'
                                : 'var(--surface2)',
                    color: status === 'running' ? meta.accent
                        : status === 'done' ? 'var(--accent)'
                            : status === 'error' ? 'var(--err)'
                                : 'var(--muted)',
                }}>
                    {status === 'idle' ? 'idle' : status}
                </span>
                {myLogs.length > 0 && (
                    <span style={{ fontSize: '10px', color: 'var(--muted)', marginLeft: 'auto', fontFamily: 'var(--font-mono)' }}>
                        {myLogs.length} step{myLogs.length !== 1 ? 's' : ''}
                    </span>
                )}
            </div>

            {latest?.output_summary && (
                <div style={{
                    marginTop: '10px', fontSize: '11px', color: 'var(--muted)',
                    fontFamily: 'var(--font-mono)', background: 'var(--surface2)',
                    borderRadius: 'var(--r-sm)', padding: '6px 8px',
                    whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
                }}>
                    {latest.output_summary.slice(0, 55)}
                </div>
            )}
        </div>
    )
}