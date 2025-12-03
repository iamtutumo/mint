"use client"

import { useCallback, useRef, useState } from "react"

interface ScribeConfig {
  modelId: "scribe_realtime_v2"
  onPartialTranscript: (data: { text?: string }) => void
  onFinalTranscript: (data: { text?: string }) => void
  onError: (error: Error | Event) => void
}

interface ScribeConnectOptions {
  token: string
  languageCode?: string
  microphone?: {
    echoCancellation: boolean
    noiseSuppression: boolean
    autoGainControl: boolean
  }
}

export function useScribe(config: ScribeConfig) {
  const [status, setStatus] = useState("idle")
  const connectionRef = useRef<any>(null)
  const transcriptsRef = useRef<string[]>([])

  const connect = useCallback(
    async (options: ScribeConnectOptions) => {
      try {
        setStatus("connecting")

        // Initialize WebSocket connection to Scribe API
        const url = new URL("wss://api.elevenlabs.io/v1/convai")
        url.searchParams.append("xi-api-key", "")

        const ws = new WebSocket(url)
        connectionRef.current = ws

        ws.onopen = () => {
          setStatus("connected")
          // Send init message with token and config
          ws.send(
            JSON.stringify({
              type: "init",
              token: options.token,
              model_id: config.modelId,
              language_code: options.languageCode,
              microphone: options.microphone,
            }),
          )
        }

        ws.onmessage = (event) => {
          try {
            const data = JSON.parse(event.data)
            if (data.type === "transcript") {
              if (data.is_final) {
                config.onFinalTranscript({ text: data.text })
              } else {
                config.onPartialTranscript({ text: data.text })
              }
            }
          } catch (error) {
            config.onError(error instanceof Error ? error : new Error("Parse error"))
          }
        }

        ws.onerror = (error) => {
          setStatus("idle")
          config.onError(error)
        }

        ws.onclose = () => {
          setStatus("idle")
        }
      } catch (error) {
        setStatus("idle")
        config.onError(error instanceof Error ? error : new Error("Connection failed"))
        throw error
      }
    },
    [config],
  )

  const disconnect = useCallback(() => {
    if (connectionRef.current) {
      connectionRef.current.close()
      connectionRef.current = null
      setStatus("idle")
    }
  }, [])

  const clearTranscripts = useCallback(() => {
    transcriptsRef.current = []
  }, [])

  return {
    status,
    connect,
    disconnect,
    clearTranscripts,
  }
}
