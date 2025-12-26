"""
Natural Language Processing (NLP) utilities for parsing user commands into structured data.
This module provides functionality to convert natural language input into actionable commands.
"""
from typing import Dict, Any, List, Optional, Union
from enum import Enum
import re
from datetime import datetime, time

class CommandType(str, Enum):
    """Supported command types for natural language processing."""
    CREATE_ORDER = "create_order"
    CHECK_STATUS = "check_status"
    CANCEL_ORDER = "cancel_order"
    BOOK_APPOINTMENT = "book_appointment"
    CHECK_INVENTORY = "check_inventory"
    GET_QUOTE = "get_quote"
    HELP = "help"
    UNKNOWN = "unknown"

class Command:
    """Represents a parsed command from natural language input."""
    
    def __init__(
        self,
        command_type: CommandType,
        entities: Dict[str, Any],
        confidence: float = 1.0,
        raw_text: str = ""
    ):
        self.command_type = command_type
        self.entities = entities
        self.confidence = confidence
        self.raw_text = raw_text
    
    def __repr__(self) -> str:
        return f"<Command {self.command_type} (confidence: {self.confidence:.2f})>"
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert the command to a dictionary."""
        return {
            "command_type": self.command_type,
            "entities": self.entities,
            "confidence": self.confidence,
            "raw_text": self.raw_text
        }

class LLMParser:
    """
    Natural Language Processing (NLP) parser for converting natural language
    input into structured command objects.
    
    This is a simplified implementation. In a production environment, you would
    typically integrate with an NLP service like Rasa, Dialogflow, or a fine-tuned LLM.
    """
    
    def __init__(self):
        # Regular expressions for simple pattern matching
        self.patterns = {
            CommandType.CREATE_ORDER: [
                r"(?:order|buy|purchase|get)\s+(\d+)\s*(?:x|of)?\s*([\w\s]+)(?:\s+for\s+\$?(\d+(?:\.\d{2})?))?",
                r"(?:i\s+want\s+to\s+)?(?:order|buy|purchase|get)\s+(?:a\s+)?([\w\s]+)(?:\s+for\s+\$?(\d+(?:\.\d{2})?))?"
            ],
            CommandType.CHECK_STATUS: [
                r"(?:status|where is|track)\s+(?:my\s+)?(?:order|purchase)\s*(?:#)?(\w+)?",
                r"(?:when\s+will\s+my\s+order\s+arrive|when\s+is\s+my\s+order\s+coming)"
            ],
            CommandType.CANCEL_ORDER: [
                r"(?:cancel|stop|delete)\s+(?:my\s+)?(?:order|purchase)\s*(?:#)?(\w+)?",
                r"i\s+want\s+to\s+cancel\s+my\s+order"
            ],
            CommandType.BOOK_APPOINTMENT: [
                r"(?:book|schedule|make an? appointment)\s+(?:for\s+)?(?:a\s+)?([\w\s]+)(?:\s+on\s+(\w+\s+\d{1,2}(?:st|nd|rd|th)?(?:\s+at\s+\d{1,2}(?::\d{2})?\s*(?:am|pm)?)?))?",
                r"i\s+need\s+(?:a\s+)?([\w\s]+?)\s*(?:appointment|service)"
            ],
            CommandType.CHECK_INVENTORY: [
                r"(?:do\s+you\s+have|is\s+there|check\s+if\s+you\s+have|inventory\s+of)\s+([\w\s]+)",
                r"(?:is|are)\s+([\w\s]+)\s+(?:available|in stock)"
            ]
        }
        
        # Keywords to identify command types
        self.keywords = {
            CommandType.HELP: ["help", "support", "assistance"],
            CommandType.CREATE_ORDER: ["order", "buy", "purchase", "get"],
            CommandType.CHECK_STATUS: ["status", "track", "where is", "when will"],
            CommandType.CANCEL_ORDER: ["cancel", "stop", "delete"],
            CommandType.BOOK_APPOINTMENT: ["book", "schedule", "appointment"],
            CommandType.CHECK_INVENTORY: ["inventory", "stock", "available", "have"]
        }
    
    def parse(self, text: str) -> Command:
        """
        Parse natural language text and return a Command object.
        
        Args:
            text: The input text to parse
            
        Returns:
            A Command object representing the parsed command
        """
        text = text.lower().strip()
        
        # Check for exact matches first
        if not text:
            return Command(CommandType.UNKNOWN, {}, 0.0, text)
        
        # Check for help command
        if any(keyword in text for keyword in self.keywords[CommandType.HELP]):
            return Command(CommandType.HELP, {"message": "How can I help you today?"}, 1.0, text)
        
        # Try to match patterns for each command type
        for command_type, patterns in self.patterns.items():
            for pattern in patterns:
                match = re.search(pattern, text, re.IGNORECASE)
                if match:
                    entities = self._extract_entities(command_type, match.groups())
                    return Command(command_type, entities, 0.9, text)
        
        # Fall back to keyword matching with lower confidence
        for command_type, keywords in self.keywords.items():
            if command_type == CommandType.HELP:
                continue
                
            if any(keyword in text for keyword in keywords):
                return Command(command_type, {"raw_text": text}, 0.7, text)
        
        # If no match found, return unknown command
        return Command(CommandType.UNKNOWN, {"raw_text": text}, 0.0, text)
    
    def _extract_entities(self, command_type: CommandType, match_groups: tuple) -> Dict[str, Any]:
        """Extract entities from regex match groups based on command type."""
        entities = {}
        
        if command_type == CommandType.CREATE_ORDER:
            if len(match_groups) >= 2:
                if match_groups[0].isdigit():
                    # Matched pattern like "order 2 x product name"
                    entities["quantity"] = int(match_groups[0])
                    entities["product"] = match_groups[1].strip()
                    if len(match_groups) > 2 and match_groups[2]:
                        entities["price"] = float(match_groups[2])
                else:
                    # Matched pattern like "order a product name"
                    entities["quantity"] = 1
                    entities["product"] = match_groups[0].strip()
                    if len(match_groups) > 1 and match_groups[1]:
                        entities["price"] = float(match_groups[1])
        
        elif command_type == CommandType.CHECK_STATUS:
            if match_groups and match_groups[0]:
                entities["order_id"] = match_groups[0].strip()
        
        elif command_type == CommandType.CANCEL_ORDER:
            if match_groups and match_groups[0]:
                entities["order_id"] = match_groups[0].strip()
        
        elif command_type == CommandType.BOOK_APPOINTMENT:
            if match_groups:
                if match_groups[0]:
                    entities["service"] = match_groups[0].strip()
                if len(match_groups) > 1 and match_groups[1]:
                    # Try to parse date/time
                    try:
                        # This is a simplified example - you'd want a more robust date parser
                        dt = datetime.strptime(match_groups[1].strip(), "%B %d at %I:%M %p")
                        entities["datetime"] = dt
                    except ValueError:
                        entities["datetime_text"] = match_groups[1].strip()
        
        elif command_type == CommandType.CHECK_INVENTORY:
            if match_groups and match_groups[0]:
                entities["product"] = match_groups[0].strip()
        
        return entities

# Singleton instance
llm_parser = LLMParser()

def parse_command(text: str) -> Command:
    ""
    Parse natural language text and return a Command object.
    
    This is a convenience function that uses the default LLMParser instance.
    
    Args:
        text: The input text to parse
        
    Returns:
        A Command object representing the parsed command
    """
    return llm_parser.parse(text)
