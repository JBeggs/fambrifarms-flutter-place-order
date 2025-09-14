"""
WhatsApp Message Parser - Extract companies and order items from messages
Handles the complex parsing logic that was previously in JavaScript
"""

import re
import json
import os
from typing import List, Dict, Any, Optional, Tuple


class MessageParser:
    def __init__(self):
        self.company_aliases = self._load_company_aliases()
        self.quantity_patterns = self._load_quantity_patterns()
        
    def _load_company_aliases(self) -> Dict[str, str]:
        """Load company aliases mapping from config file"""
        try:
            config_path = os.path.join(os.path.dirname(__file__), '..', '..', 'config', 'company_aliases.json')
            if os.path.exists(config_path):
                with open(config_path, 'r') as f:
                    config = json.load(f)
                    return config.get('company_aliases', {})
        except Exception as e:
            print(f"⚠️ Failed to load company aliases config: {e}")
        
        # Fallback to default aliases
        return {
            "mugg and bean": "Mugg and Bean",
            "mugg bean": "Mugg and Bean", 
            "mugg": "Mugg and Bean",
            "venue": "Venue",
            "debonairs": "Debonairs",
            "t-junction": "T-junction",
            "t junction": "T-junction",
            "wimpy": "Wimpy",
            "wimpy mooinooi": "Wimpy",
            "shebeen": "Shebeen",
            "casa bella": "Casa Bella",
            "casabella": "Casa Bella",
            "luma": "Luma",
            "marco": "Marco",
            "maltos": "Maltos"
        }
    
    def _load_quantity_patterns(self) -> List[str]:
        """Load quantity detection patterns from config file"""
        try:
            config_path = os.path.join(os.path.dirname(__file__), '..', '..', 'config', 'company_aliases.json')
            if os.path.exists(config_path):
                with open(config_path, 'r') as f:
                    config = json.load(f)
                    return config.get('quantity_patterns', [])
        except Exception as e:
            print(f"⚠️ Failed to load quantity patterns config: {e}")
        
        # Fallback to default patterns
        return [
            r'\d+\s*x\s*\d*\s*kg',  # 2x5kg, 10x kg
            r'\d+\s*kg',            # 10kg, 5 kg
            r'\d+\s*box',           # 3box, 5 box
            r'\d+\s*boxes',         # 3boxes
            r'x\d+',                # x3, x12
            r'\d+x',                # 3x, 12x
            r'\d+\*',               # 3*, 5*
            r'\d+\s*pcs',           # 5pcs, 10 pcs
            r'\d+\s*pieces',        # 5pieces
            r'\d+\s*pkts',          # 6pkts
            r'\d+\s*packets',       # 6packets
            r'\d+\s*heads',         # 5heads
            r'\d+\s*bunches',       # 10bunches
        ]
    
    def to_canonical_company(self, text: str) -> Optional[str]:
        """Convert text to canonical company name"""
        if not text:
            return None
            
        text_lower = text.lower().strip()
        
        # Direct match
        if text_lower in self.company_aliases:
            return self.company_aliases[text_lower]
            
        # Partial match
        for alias, canonical in self.company_aliases.items():
            if alias in text_lower or text_lower in alias:
                return canonical
                
        return None
    
    def has_quantity_indicators(self, text: str) -> bool:
        """Check if text contains quantity indicators"""
        if not text:
            return False
            
        text_upper = text.upper()
        for pattern in self.quantity_patterns:
            if re.search(pattern, text_upper, re.IGNORECASE):
                return True
                
        return False
    
    def is_likely_order_item(self, text: str) -> bool:
        """Check if text looks like an order item"""
        if not text or len(text.strip()) < 3:
            return False
            
        text = text.strip()
        
        # Has quantity indicators
        if self.has_quantity_indicators(text):
            return True
            
        # Contains food/product keywords
        food_keywords = [
            'tomato', 'potato', 'onion', 'lettuce', 'spinach', 'carrot',
            'mushroom', 'pepper', 'cucumber', 'broccoli', 'cauliflower',
            'cabbage', 'rocket', 'lemon', 'orange', 'banana', 'apple',
            'avocado', 'corn', 'butternut', 'marrow', 'chilli', 'basil',
            'parsley', 'coriander', 'rosemary', 'strawberry', 'lime',
            'naartjie', 'ginger', 'garlic', 'herbs', 'greens'
        ]
        
        text_lower = text.lower()
        for keyword in food_keywords:
            if keyword in text_lower:
                return True
                
        return False
    
    def extract_order_items(self, text: str) -> List[str]:
        """Extract order items from multi-line text"""
        if not text:
            return []
            
        lines = [line.strip() for line in text.split('\n') if line.strip()]
        items = []
        
        for line in lines:
            # Skip greetings and instructions
            if self._is_greeting_or_instruction(line):
                continue
                
            # Skip company names
            if self.to_canonical_company(line):
                continue
                
            # Check if it's likely an order item
            if self.is_likely_order_item(line):
                items.append(line)
                
        return items
    
    def extract_instructions(self, text: str) -> List[str]:
        """Extract instructions/greetings from text"""
        if not text:
            return []
            
        lines = [line.strip() for line in text.split('\n') if line.strip()]
        instructions = []
        
        for line in lines:
            if self._is_greeting_or_instruction(line) and not self.is_likely_order_item(line):
                instructions.append(line)
                
        return instructions
    
    def _is_greeting_or_instruction(self, text: str) -> bool:
        """Check if text is a greeting or instruction"""
        if not text:
            return False
            
        text_upper = text.upper()
        
        greeting_keywords = [
            'GOOD MORNING', 'MORNING', 'HELLO', 'HI', 'HALLO',
            'THANKS', 'THANK YOU', 'PLEASE', 'PLZ', 'PLIZ',
            'NOTE', 'REMEMBER', 'SEPARATE INVOICE', 'SEPERATE INVOICE',
            'THAT\'S ALL', 'THATS ALL', 'TNX', 'CHEERS'
        ]
        
        for keyword in greeting_keywords:
            if keyword in text_upper:
                return True
                
        return False
    
    def parse_messages_to_orders(self, messages: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Parse a list of WhatsApp messages into orders with company assignments
        
        This implements the complex parsing logic that handles:
        1. Items-before-company-name patterns
        2. Company-only messages
        3. Mixed content messages
        """
        if not messages:
            return []
            
        orders = []
        current_buffer = []  # Buffer for items waiting for company assignment
        
        for i, message in enumerate(messages):
            content = message.get('content', '').strip()
            if not content:
                continue
                
            # Split message into lines
            lines = [line.strip() for line in content.split('\n') if line.strip()]
            if not lines:
                continue
                
            # Check if this is a company-only message
            if len(lines) == 1:
                company = self.to_canonical_company(lines[0])
                if company:
                    # This is a company name - flush buffer to this company
                    if current_buffer:
                        order = self._create_order_from_buffer(company, current_buffer, message)
                        if order:
                            orders.append(order)
                        current_buffer = []
                    continue
            
            # Check for items-before-company pattern
            # Look for items in current message and company in next message
            has_items = any(self.is_likely_order_item(line) for line in lines)
            
            if has_items and i + 1 < len(messages):
                next_message = messages[i + 1]
                next_content = next_message.get('content', '').strip()
                next_lines = [line.strip() for line in next_content.split('\n') if line.strip()]
                
                if len(next_lines) == 1:
                    next_company = self.to_canonical_company(next_lines[0])
                    if next_company:
                        # Pattern: current message has items, next message is company
                        items = self.extract_order_items(content)
                        instructions = self.extract_instructions(content)
                        
                        if items:
                            order = {
                                'company_name': next_company,
                                'items_text': items,
                                'instructions': instructions,
                                'timestamp': message.get('timestamp', ''),
                                'message_ids': [message.get('id', ''), next_message.get('id', '')]
                            }
                            orders.append(order)
                        continue
            
            # Check for mixed content (items + company in same message)
            company_in_message = None
            for line in lines:
                company = self.to_canonical_company(line)
                if company:
                    company_in_message = company
                    break
                    
            if company_in_message and has_items:
                # Mixed content - extract items and assign to company
                items = self.extract_order_items(content)
                instructions = self.extract_instructions(content)
                
                if items:
                    order = {
                        'company_name': company_in_message,
                        'items_text': items,
                        'instructions': instructions,
                        'timestamp': message.get('timestamp', ''),
                        'message_ids': [message.get('id', '')]
                    }
                    orders.append(order)
                continue
            
            # If message has items but no company, add to buffer
            if has_items:
                current_buffer.extend(self.extract_order_items(content))
                buffer_instructions = self.extract_instructions(content)
                if buffer_instructions:
                    current_buffer.extend(buffer_instructions)
        
        # Consolidate orders for the same company
        return self._consolidate_orders(orders)
    
    def _create_order_from_buffer(self, company: str, buffer: List[str], message: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Create an order from buffered items"""
        if not buffer:
            return None
            
        items = [item for item in buffer if self.is_likely_order_item(item)]
        instructions = [item for item in buffer if not self.is_likely_order_item(item)]
        
        if not items:
            return None
            
        return {
            'company_name': company,
            'items_text': items,
            'instructions': instructions,
            'timestamp': message.get('timestamp', ''),
            'message_ids': [message.get('id', '')]
        }
    
    def _consolidate_orders(self, orders: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Consolidate multiple orders for the same company"""
        if not orders:
            return []
            
        company_orders = {}
        
        for order in orders:
            company = order['company_name']
            if company not in company_orders:
                company_orders[company] = {
                    'company_name': company,
                    'items_text': [],
                    'instructions': [],
                    'timestamp': order['timestamp'],
                    'message_ids': []
                }
            
            # Merge items and instructions
            company_orders[company]['items_text'].extend(order['items_text'])
            company_orders[company]['instructions'].extend(order['instructions'])
            company_orders[company]['message_ids'].extend(order['message_ids'])
            
            # Keep earliest timestamp
            if order['timestamp'] < company_orders[company]['timestamp']:
                company_orders[company]['timestamp'] = order['timestamp']
        
        return list(company_orders.values())
