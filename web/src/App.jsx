import { useState, useCallback } from 'react'
import AgentCard from './components/AgentCard.jsx'
import LogStream from './components/LogStream'
import ResultPanel from './components/ResultPanel.jsx'
import QuickMessages from './components/QuickMessages.jsx'
import { useOrchestrationLogs } from './hooks/useOrchestrationLogs.js'

const AGENTS = ['Orchestrator', 'Gatekeeper', 'Negotiator', 'Matchmaker', 'Janitor', 'Recommender']
const BACKEND_URL = import.meta.env.VITE_BACKEND_URL || 'http://localhost:3000'

export default function App() {
  const [message, setMessage] = useState('')
  const [agentId, setAgentId] = useState('03001234567')
  const [sessionId, setSessionId] = useState(null)
  const [result, setResult] = useState(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)

  const logs = useOrchestrationLogs(sessionId)

  const send = useCallback(async () => {
    const txt = message.trim()
    if (!txt || loading) return
    setLoading(true)
    setError(null)
    setResult(null)

    // Session ID backend se aayega — pehle null rakho
    setSessionId(null)

    try {
      const res = await fetch(`${BACKEND_URL}/api/message`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ raw_text: txt, sender_agent_id: agentId, source: 'app' }),
      })
      const data = await res.json()

      // Backend ka session_id use karo — frontend wala nahi
      if (data.session_id) {
        setSessionId(data.session_id)
      }

      setResult(data)
    } catch (e) {
      setError(e.message)
    } finally {
      setLoading(false)
    }
  }, [message, agentId, loading])

  const confirm = useCallback(async (parsedData, sessionId) => {
    setLoading(true)
    try {
      const res = await fetch(`${BACKEND_URL}/api/confirm`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          parsed_data: parsedData,
          sender_agent_id: agentId,
          session_id: sessionId,
        }),
      })
      const data = await res.json()
      setResult(data)
    } catch (e) {
      setError(e.message)
    } finally {
      setLoading(false)
    }
  }, [agentId])

  const cancel = useCallback(() => {
    setResult(null)
    setMessage('')
  }, [])

  const onKeyDown = e => {
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') send()
  }

  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>

      {/* Header */}
      <header style={{
        display: 'flex', alignItems: 'center', gap: '12px',
        padding: '1rem 1.5rem',
        borderBottom: '1px solid var(--border)',
        background: 'var(--surface)',
        position: 'sticky', top: 0, zIndex: 10,
      }}>
        <div style={{
          width: '30px', height: '30px', borderRadius: '8px',
          background: 'var(--accent-dim)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: '16px',
        }}>🔗</div>
        <div>
          <div style={{ fontWeight: 600, fontSize: '15px', letterSpacing: '-.01em' }}>Raabta AI</div>
          <div style={{ fontSize: '11px', color: 'var(--muted)', fontFamily: 'var(--font-mono)' }}>
            orchestration demo
          </div>
        </div>
        <div style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: '10px' }}>
          {sessionId && (
            <span style={{
              fontFamily: 'var(--font-mono)', fontSize: '10px',
              color: 'var(--muted)', background: 'var(--surface2)',
              padding: '3px 8px', borderRadius: '10px',
            }}>
              {sessionId.slice(-8)}
            </span>
          )}
          <div style={{
            width: '7px', height: '7px', borderRadius: '50%',
            background: loading ? 'var(--warn)' : '#4ade80',
            boxShadow: loading
              ? '0 0 0 3px rgba(245,158,11,.2)'
              : '0 0 0 3px rgba(74,222,128,.2)',
            transition: 'all .3s',
          }} />
        </div>
      </header>

      <main style={{
        flex: 1, display: 'grid',
        gridTemplateColumns: '1fr 320px',
        minHeight: 0,
      }}>

        {/* Left panel */}
        <div style={{
          padding: '1.25rem',
          display: 'flex', flexDirection: 'column', gap: '1.25rem',
          overflowY: 'auto',
        }}>

          {/* Input card */}
          <div style={{
            background: 'var(--surface)',
            border: '1px solid var(--border)',
            borderRadius: 'var(--r)',
            padding: '1rem 1.25rem',
          }}>
            <div style={{
              fontSize: '10px', fontFamily: 'var(--font-mono)',
              color: 'var(--muted)', textTransform: 'uppercase',
              letterSpacing: '.08em', marginBottom: '10px',
            }}>
              Message Simulator
            </div>

            <textarea
              value={message}
              onChange={e => setMessage(e.target.value)}
              onKeyDown={onKeyDown}
              rows={3}
              placeholder="e.g. Block N mein 400gz plot hai, demand 4cr. Public karo."
              style={{
                width: '100%', background: 'var(--surface2)',
                border: '1px solid var(--border)',
                borderRadius: 'var(--r-sm)',
                padding: '10px 12px', fontSize: '13px',
                fontFamily: 'var(--font-sans)', color: 'var(--text)',
                resize: 'none', lineHeight: 1.6, outline: 'none',
                transition: 'border-color .2s',
              }}
              onFocus={e => e.target.style.borderColor = 'var(--border-hi)'}
              onBlur={e => e.target.style.borderColor = 'var(--border)'}
            />

            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginTop: '10px' }}>
              <input
                value={agentId}
                onChange={e => setAgentId(e.target.value)}
                placeholder="Agent phone number"
                style={{
                  flex: 1, background: 'var(--surface2)',
                  border: '1px solid var(--border)',
                  borderRadius: 'var(--r-sm)',
                  padding: '7px 12px', fontSize: '12px',
                  fontFamily: 'var(--font-mono)',
                  color: 'var(--muted)', outline: 'none',
                }}
              />
              <button
                onClick={send}
                disabled={loading || !message.trim()}
                style={{
                  background: loading || !message.trim() ? 'var(--surface2)' : 'var(--accent)',
                  color: loading || !message.trim() ? 'var(--muted)' : '#0d0d0d',
                  border: 'none',
                  borderRadius: 'var(--r-sm)',
                  padding: '8px 20px',
                  fontSize: '13px', fontWeight: 500,
                  cursor: loading ? 'not-allowed' : 'pointer',
                  fontFamily: 'var(--font-sans)',
                  transition: 'all .2s', whiteSpace: 'nowrap',
                }}
              >
                {loading ? 'Sending...' : 'Send ↗'}
              </button>
            </div>

            <QuickMessages onSelect={msg => setMessage(msg)} />

            {/* Quick Diagnostic Actions Bar */}
            <div style={{ 
              display: 'flex', 
              alignItems: 'center', 
              gap: '8px', 
              marginTop: '12px', 
              paddingTop: '12px',
              borderTop: '1px dashed var(--border)' 
            }}>
              <span style={{ fontSize: '10px', fontFamily: 'var(--font-mono)', color: 'var(--muted)' }}>
                Agent Tools:
              </span>
              <button
                onClick={async () => {
                  setLoading(true);
                  setError(null);
                  setResult(null);
                  try {
                    const res = await fetch(`${BACKEND_URL}/api/janitor/run`, { method: 'POST' });
                    const data = await res.json();
                    setResult({ status: 'janitor_result', stats_updated_count: data.stats_updated_count, archived_count: data.archived_count });
                  } catch (e) {
                    setError(e.message);
                  } finally {
                    setLoading(false);
                  }
                }}
                disabled={loading}
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
                onMouseEnter={e => { e.target.style.color = 'var(--text)'; e.target.style.borderColor = 'var(--border-hi)'; }}
                onMouseLeave={e => { e.target.style.color = 'var(--muted)'; e.target.style.borderColor = 'var(--border)'; }}
              >
                🧹 Run Janitor Sweep
              </button>
              <button
                onClick={async () => {
                  setLoading(true);
                  setError(null);
                  setResult(null);
                  try {
                    const res = await fetch(`${BACKEND_URL}/api/recommender/run`, {
                      method: 'POST',
                      headers: { 'Content-Type': 'application/json' },
                      body: JSON.stringify({ agent_id: agentId })
                    });
                    const data = await res.json();
                    setResult({ status: 'recommender_result', recommendations: data.recommendations });
                  } catch (e) {
                    setError(e.message);
                  } finally {
                    setLoading(false);
                  }
                }}
                disabled={loading}
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
                onMouseEnter={e => { e.target.style.color = 'var(--text)'; e.target.style.borderColor = 'var(--border-hi)'; }}
                onMouseLeave={e => { e.target.style.color = 'var(--muted)'; e.target.style.borderColor = 'var(--border)'; }}
              >
                💡 Get Market Insights
              </button>
            </div>

            {error && (
              <div style={{
                marginTop: '10px', fontSize: '11px',
                fontFamily: 'var(--font-mono)', color: 'var(--err)',
                background: 'var(--err-dim)', borderRadius: 'var(--r-sm)',
                padding: '8px 10px',
              }}>
                {error}
              </div>
            )}
          </div>

          {/* Agent cards */}
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(155px, 1fr))',
            gap: '10px',
          }}>
            {AGENTS.map(name => (
              <AgentCard key={name} name={name} logs={logs} />
            ))}
          </div>

          {/* Flow pipeline */}
          <div style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            padding: '10px 1rem',
            background: 'var(--surface)', border: '1px solid var(--border)',
            borderRadius: 'var(--r)',
            fontFamily: 'var(--font-mono)', fontSize: '11px',
          }}>
            {['Parse', '→', 'Validate', '→', 'Save', '→', 'Match', '→', 'Notify'].map((s, i) => (
              <span key={i} style={{
                color: s === '→' ? 'var(--border-hi)' : 'var(--muted)',
                fontWeight: s !== '→' ? 500 : 400,
              }}>{s}</span>
            ))}
          </div>

          {/* Log stream */}
          <div style={{
            background: 'var(--surface)', border: '1px solid var(--border)',
            borderRadius: 'var(--r)', padding: '1rem',
            minHeight: '200px', maxHeight: '320px',
            overflowY: 'auto', display: 'flex', flexDirection: 'column',
          }}>
            <div style={{
              fontSize: '10px', fontFamily: 'var(--font-mono)',
              color: 'var(--muted)', textTransform: 'uppercase',
              letterSpacing: '.08em', marginBottom: '10px',
              display: 'flex', alignItems: 'center', gap: '6px',
            }}>
              Live Log
              {logs.length > 0 && (
                <span style={{ background: 'var(--surface2)', padding: '1px 6px', borderRadius: '10px' }}>
                  {logs.length}
                </span>
              )}
            </div>
            <LogStream logs={logs} />
          </div>
        </div>

        {/* Right panel — Result */}
        <aside style={{
          borderLeft: '1px solid var(--border)',
          padding: '1.25rem',
          display: 'flex', flexDirection: 'column', gap: '1rem',
          overflowY: 'auto',
          background: 'var(--surface)',
        }}>
          <div style={{
            fontSize: '10px', fontFamily: 'var(--font-mono)',
            color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '.08em',
          }}>
            Result
          </div>
          <ResultPanel result={result ? { ...result, onConfirm: confirm, onCancel: cancel } : null} />
        </aside>
      </main>

      <style>{`
        @keyframes slide {
          from { background-position: 200% center; }
          to   { background-position: -200% center; }
        }
        @keyframes blink { 0%,100%{opacity:1} 50%{opacity:.3} }
        @keyframes fadeUp { from{opacity:0;transform:translateY(4px)} to{opacity:1;transform:none} }
      `}</style>
    </div>
  )
}