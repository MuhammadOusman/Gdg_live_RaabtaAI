import { useState, useEffect, useRef } from 'react'
import { supabase } from '../services/supabase'

export function useOrchestrationLogs(sessionId) {
    const [logs, setLogs] = useState([])
    const channelRef = useRef(null)

    useEffect(() => {
        if (!sessionId) return
        console.log('[Realtime] Session:', sessionId)
        console.log('[Realtime] URL:', import.meta.env.VITE_SUPABASE_URL)

        supabase
            .from('orchestration_logs')
            .select('*')
            .eq('session_id', sessionId)
            .order('created_at', { ascending: true })
            .then(({ data, error }) => {
                if (data) setLogs(data)
            })

        channelRef.current = supabase
            .channel(`logs-${sessionId}`)
            .on('postgres_changes', {
                event: 'INSERT',
                schema: 'public',
                table: 'orchestration_logs',
                filter: `session_id=eq.${sessionId}`,
            }, payload => {
                setLogs(prev => [...prev, payload.new])
            })
            .subscribe()

        return () => {
            if (channelRef.current) supabase.removeChannel(channelRef.current)
        }
    }, [sessionId])

    return logs
}