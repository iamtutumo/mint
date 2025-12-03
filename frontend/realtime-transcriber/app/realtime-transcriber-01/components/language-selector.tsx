"use client"

import { useState } from "react"
import { ChevronDown } from "lucide-react"

const LANGUAGES = [
  { code: "en", name: "English" },
  { code: "es", name: "Spanish" },
  { code: "fr", name: "French" },
  { code: "de", name: "German" },
  { code: "it", name: "Italian" },
  { code: "pt", name: "Portuguese" },
  { code: "nl", name: "Dutch" },
  { code: "pl", name: "Polish" },
  { code: "ru", name: "Russian" },
  { code: "ja", name: "Japanese" },
  { code: "zh", name: "Chinese" },
  { code: "ko", name: "Korean" },
]

interface LanguageSelectorProps {
  value: string | null
  onValueChange: (value: string | null) => void
  disabled?: boolean
}

export function LanguageSelector({ value, onValueChange, disabled = false }: LanguageSelectorProps) {
  const [isOpen, setIsOpen] = useState(false)

  const selectedLanguage = LANGUAGES.find((lang) => lang.code === value)

  return (
    <div className="relative w-full">
      <button
        onClick={() => !disabled && setIsOpen(!isOpen)}
        disabled={disabled}
        className="flex w-full items-center justify-between rounded-lg border border-border bg-background px-4 py-2.5 text-sm font-medium text-foreground transition-colors hover:bg-accent disabled:opacity-50 disabled:cursor-not-allowed"
      >
        <span>{selectedLanguage?.name || "Select language"}</span>
        <ChevronDown
          className="h-4 w-4 transition-transform"
          style={{ transform: isOpen ? "rotate(180deg)" : "rotate(0deg)" }}
        />
      </button>

      {isOpen && !disabled && (
        <div className="absolute top-full left-0 right-0 z-50 mt-2 rounded-lg border border-border bg-background shadow-lg">
          <div className="max-h-48 overflow-y-auto">
            {LANGUAGES.map((lang) => (
              <button
                key={lang.code}
                onClick={() => {
                  onValueChange(lang.code)
                  setIsOpen(false)
                }}
                className={`w-full text-left px-4 py-2.5 text-sm transition-colors ${
                  value === lang.code ? "bg-primary text-primary-foreground" : "hover:bg-accent"
                }`}
              >
                {lang.name}
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
