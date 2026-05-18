export default function ResultPanel({ result }) {
    if (!result) return (
        <div style={{
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            height: '100%', color: 'var(--muted)',
            fontFamily: 'var(--font-mono)', fontSize: '12px',
        }}>
            result will appear here
        </div>
    )

    const { status } = result

    if (status === 'listing_saved') {
        const l = result.listing || {}
        return (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                <StatusChip color="#4ade80" label="Listing Saved" />
                <InfoRow label="Block" value={l.block_id} />
                <InfoRow label="Size" value={`${l.size} ${l.unit}`} />
                <InfoRow label="Price" value={`PKR ${(l.demand_price || 0).toLocaleString('en-PK')}`} />
                <InfoRow label="Features" value={l.features?.join(', ') || 'None'} />
                <InfoRow label="Visibility" value={l.is_public ? '🌐 Public' : '🔒 Private'} />
                <Ambiguities items={result.ambiguities} />
            </div>
        )
    }

    if (status === 'awaiting_confirm') {
        return (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                <StatusChip color="#a78bfa" label="Awaiting Confirmation" />
                <pre style={{
                    fontFamily: 'var(--font-mono)', fontSize: '11px', color: 'var(--muted)',
                    whiteSpace: 'pre-wrap', background: 'var(--surface2)',
                    borderRadius: 'var(--r-sm)', padding: '10px', lineHeight: 1.7,
                }}>
                    {result.preview?.slice(0, 400)}
                </pre>
                {result.maps_link && (
                    <a href={result.maps_link} target="_blank" rel="noreferrer" style={{
                        fontSize: '12px', color: 'var(--blue)',
                        fontFamily: 'var(--font-mono)', textDecoration: 'none', opacity: .8,
                    }}>
                        🗺 View on Maps →
                    </a>
                )}

                <Ambiguities items={result.ambiguities} />
                {/* CONFIRM BUTTON */}
                <div style={{ display: 'flex', gap: '8px', marginTop: '4px' }}>
                    <button
                        onClick={() => result.onConfirm && result.onConfirm(result.parsed, result.session_id)}
                        style={{
                            flex: 1, background: 'var(--accent)', color: '#0d0d0d',
                            border: 'none', borderRadius: 'var(--r-sm)',
                            padding: '9px 0', fontSize: '13px', fontWeight: 500,
                            cursor: 'pointer', fontFamily: 'var(--font-sans)',
                        }}
                    >
                        ✓ Confirm & Save
                    </button>
                    <button
                        onClick={() => result.onCancel && result.onCancel()}
                        style={{
                            flex: 1, background: 'var(--surface2)', color: 'var(--muted)',
                            border: '1px solid var(--border)', borderRadius: 'var(--r-sm)',
                            padding: '9px 0', fontSize: '13px',
                            cursor: 'pointer', fontFamily: 'var(--font-sans)',
                        }}
                    >
                        ✕ Cancel
                    </button>
                </div>
            </div>
        )
    }

    if (status === 'demand_saved') {
        return (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                <StatusChip color="#60a5fa" label={`Demand Saved • ${result.match_count} match(es)`} />
                {(result.immediate_matches || []).slice(0, 4).map((m, i) => (
                    <div key={i} style={{
                        background: 'var(--surface2)',
                        border: '1px solid rgba(74,222,128,.2)',
                        borderRadius: 'var(--r-sm)', padding: '8px 12px',
                        borderLeft: '3px solid #4ade80',
                    }}>
                        <div style={{ fontWeight: 500, fontSize: '13px' }}>{m.block_id}</div>
                        <div style={{ color: 'var(--muted)', fontSize: '11px', fontFamily: 'var(--font-mono)', marginTop: '2px' }}>
                            {m.size}gz • PKR {(m.demand_price || 0).toLocaleString('en-PK')}
                            {m.features?.length > 0 && ` • ${m.features.join(', ')}`}
                        </div>
                    </div>
                ))}
                {result.match_count === 0 && (
                    <div style={{ fontSize: '12px', color: 'var(--muted)', fontFamily: 'var(--font-mono)' }}>
                        Watching for future matches...
                    </div>
                )}
                <Ambiguities items={result.ambiguities} />
            </div>
        )
    }

    if (status === 'market_query_result') {
        const stats = result.stats || {};
        return (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                <StatusChip color="#f59e0b" label={`Market Query — ${result.block_id}`} />
                
                <div style={{
                    background: 'var(--surface2)', border: '1px solid var(--border)',
                    borderRadius: 'var(--r-sm)', padding: '12px',
                    display: 'flex', flexDirection: 'column', gap: '8px'
                }}>
                    <InfoRow label="Active Supply" value={`${stats.supply || 0} plot(s)`} />
                    <InfoRow label="Active Demands" value={`${stats.demand || 0} request(s)`} />
                    <InfoRow label="Demand Ratio" value={stats.demand_ratio !== undefined ? Number(stats.demand_ratio).toFixed(2) : '0.00'} />
                </div>

                <div style={{
                    fontSize: '10px', fontFamily: 'var(--font-mono)',
                    color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '.06em',
                    marginTop: '4px'
                }}>
                    💡 Recommender Advice
                </div>
                
                <div style={{
                    background: 'rgba(245,158,11,.06)',
                    border: '1px solid rgba(245,158,11,.2)',
                    borderRadius: 'var(--r-sm)', padding: '12px',
                    fontSize: '12px', color: 'var(--text)',
                    lineHeight: 1.6, fontFamily: 'var(--font-sans)'
                }}>
                    {result.advice}
                </div>
            </div>
        )
    }

    if (status === 'janitor_result') {
        return (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                <StatusChip color="#9ca3af" label="Janitor Review Completed" />
                <div style={{
                    background: 'var(--surface2)', border: '1px solid var(--border)',
                    borderRadius: 'var(--r-sm)', padding: '12px',
                    display: 'flex', flexDirection: 'column', gap: '8px'
                }}>
                    <InfoRow label="Dynamic View Count" value={`${result.stats_updated_count} Block(s)`} />
                    <InfoRow label="Archived Stale Count" value={`${result.archived_count} Listing(s)`} />
                    <InfoRow label="DB View Diagnostic" value="Active ✓" />
                </div>
            </div>
        )
    }

    if (status === 'recommender_result') {
        return (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                <StatusChip color="#f59e0b" label="Broker Market Insights" />
                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                    {result.recommendations.map((rec, i) => (
                        <div key={i} style={{
                            background: 'var(--surface2)',
                            border: '1px solid rgba(245,158,11,.15)',
                            borderRadius: 'var(--r-sm)', padding: '10px 12px',
                            borderLeft: `3px solid ${rec.priority === 'high' ? '#ef4444' : rec.priority === 'medium' ? '#f59e0b' : '#3b82f6'}`,
                        }}>
                            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '4px' }}>
                                <span style={{ fontWeight: 600, fontSize: '13px', color: 'var(--text)' }}>{rec.title}</span>
                                <span style={{
                                    fontSize: '9px', fontFamily: 'var(--font-mono)',
                                    padding: '1px 5px', borderRadius: '10px',
                                    background: rec.priority === 'high' ? 'rgba(239,68,68,.15)' : 'rgba(245,158,11,.15)',
                                    color: rec.priority === 'high' ? '#f87171' : '#fbbf24'
                                }}>
                                    {rec.priority}
                                </span>
                            </div>
                            <p style={{ margin: 0, fontSize: '11px', color: 'var(--muted)', lineHeight: 1.6 }}>
                                {rec.message}
                            </p>
                        </div>
                    ))}
                    {result.recommendations.length === 0 && (
                        <div style={{ fontSize: '12px', color: 'var(--muted)', fontFamily: 'var(--font-mono)' }}>
                            No recommendations at this time. Keep trading!
                        </div>
                    )}
                </div>
            </div>
        )
    }

    if (status === 'conflict') {
        return (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                <StatusChip color="#f59e0b" label="Duplicate Detected" />
                <div style={{
                    background: 'rgba(245,158,11,.08)',
                    border: '1px solid rgba(245,158,11,.25)',
                    borderRadius: 'var(--r-sm)', padding: '12px',
                    fontSize: '12px', fontFamily: 'var(--font-mono)',
                    whiteSpace: 'pre-wrap', lineHeight: 1.7, color: 'var(--text)',
                }}>
                    {result.conflict_message}
                </div>
            </div>
        )
    }

    if (status === 'unknown_intent') {
        return (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                <StatusChip color="#f59e0b" label="Intent Unclear" />
                <div style={{
                    background: 'rgba(245,158,11,.08)', border: '1px solid rgba(245,158,11,.25)',
                    borderRadius: 'var(--r-sm)', padding: '12px',
                    fontSize: '12px', fontFamily: 'var(--font-mono)', color: 'var(--text)', lineHeight: 1.7,
                }}>
                    {result.message}
                </div>
            </div>
        )
    }

    if (status === 'ai_unavailable') {
        return (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                <StatusChip color="#f87171" label="AI Unavailable" />
                <div style={{
                    background: 'var(--err-dim)', border: '1px solid rgba(248,113,113,.25)',
                    borderRadius: 'var(--r-sm)', padding: '12px',
                    fontSize: '12px', fontFamily: 'var(--font-mono)', color: 'var(--text)', lineHeight: 1.7,
                }}>
                    {result.message || 'AI service temporarily unavailable. Please try again.'}
                </div>
            </div>
        )
    }

    if (status === 'error') {
        return (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                <StatusChip color="#f87171" label={`Error${result.code ? ` — ${result.code}` : ''}`} />
                <div style={{
                    background: 'var(--err-dim)', border: '1px solid rgba(248,113,113,.25)',
                    borderRadius: 'var(--r-sm)', padding: '12px',
                    fontSize: '12px', fontFamily: 'var(--font-mono)', color: 'var(--err)', lineHeight: 1.7,
                }}>
                    {result.message}
                </div>
            </div>
        )
    }

    return (
        <pre style={{
            fontFamily: 'var(--font-mono)', fontSize: '10px',
            color: 'var(--muted)', whiteSpace: 'pre-wrap', overflow: 'auto',
        }}>
            {JSON.stringify(result, null, 2)}
        </pre>
    )
}

function StatusChip({ color, label }) {
    return (
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: color, flexShrink: 0 }} />
            <span style={{ fontSize: '13px', fontWeight: 500, color }}>{label}</span>
        </div>
    )
}

function InfoRow({ label, value }) {
    return (
        <div style={{
            display: 'flex', justifyContent: 'space-between', alignItems: 'center',
            padding: '4px 0', borderBottom: '1px solid var(--border)',
        }}>
            <span style={{ fontSize: '11px', color: 'var(--muted)', fontFamily: 'var(--font-mono)' }}>{label}</span>
            <span style={{ fontSize: '12px', fontFamily: 'var(--font-mono)', color: 'var(--text)' }}>{value}</span>
        </div>
    )
}

function Ambiguities({ items }) {
    if (!items || items.length === 0) return null
    return (
        <div style={{
            background: 'rgba(245,158,11,.07)',
            border: '1px solid rgba(245,158,11,.2)',
            borderRadius: 'var(--r-sm)', padding: '8px 10px',
            display: 'flex', flexDirection: 'column', gap: '4px',
        }}>
            <span style={{ fontSize: '10px', fontFamily: 'var(--font-mono)', color: '#f59e0b', textTransform: 'uppercase', letterSpacing: '.06em' }}>
                ⚠ Ambiguities
            </span>
            {items.map((a, i) => (
                <span key={i} style={{ fontSize: '11px', fontFamily: 'var(--font-mono)', color: 'var(--muted)' }}>
                    · {a}
                </span>
            ))}
        </div>
    )
}