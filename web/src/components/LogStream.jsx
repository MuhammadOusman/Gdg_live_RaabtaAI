import { useEffect, useRef } from 'react'

const AGENT_COLORS = {
    Gatekeeper: '#a78bfa',
    Negotiator: '#f59e0b',
    Matchmaker: '#4ade80',
    Orchestrator: '#60a5fa',
    Janitor: '#9ca3af',
    Recommender: '#f59e0b',
}

export default function LogStream({ logs }) {
    const bottomRef = useRef(null)

    useEffect(() => {
        bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
    }, [logs])

    if (logs.length === 0) return (
        <div style={{
            display: 'flex', flexDirection: 'column', alignItems: 'center',
            justifyContent: 'center', height: '100%', gap: '8px',
            color: 'var(--muted)', fontFamily: 'var(--font-mono)', fontSize: '12px',
        }}>
            <span style={{ fontSize: '24px', opacity: .3 }}>_</span>
            awaiting session...
        </div>
    )

    return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
            {logs.map((log, i) => {
                const color = AGENT_COLORS[log.agent_name] || '#9ca3af'
                const isRunning = log.status === 'running'
                return (
                    <div key={log.id || i} style={{
                        display: 'grid',
                        gridTemplateColumns: '90px 110px 1fr auto',
                        gap: '8px',
                        alignItems: 'center',
                        padding: '5px 10px',
                        borderRadius: 'var(--r-sm)',
                        background: i % 2 === 0 ? 'var(--surface2)' : 'transparent',
                        fontFamily: 'var(--font-mono)',
                        fontSize: '11px',
                        animation: 'fadeUp .2s ease',
                    }}>
                        <span style={{ color, fontWeight: 500, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                            {log.agent_name}
                        </span>
                        <span style={{ color: 'var(--muted)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                            {log.step}
                        </span>
                        <span style={{ color: 'var(--text)', opacity: .6, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                            {log.output_summary || log.input_summary || '—'}
                        </span>
                        <span style={{
                            fontSize: '9px', padding: '1px 6px', borderRadius: '10px', flexShrink: 0,
                            background: isRunning ? `${color}22` : 'rgba(74,222,128,.12)',
                            color: isRunning ? color : '#4ade80',
                        }}>
                            {log.status}
                        </span>
                    </div>
                )
            })}
            <div ref={bottomRef} />
        </div>
    )
}