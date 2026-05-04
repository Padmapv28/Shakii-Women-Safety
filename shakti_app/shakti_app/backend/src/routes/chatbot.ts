import { Router, Request, Response } from 'express';
import Anthropic from '@anthropic-ai/sdk';

const router = Router();
const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

const SYSTEM_PROMPT = `You are Shakti Assistant — a compassionate, calm, and practical safety advisor 
built into a women's safety app for Bengaluru, India.

Your role:
- Help users who feel unsafe with immediate, actionable advice
- Explain app features (SOS, guardians, map)
- Provide India-specific emergency numbers
- Guide users through stressful situations with empathy
- Give legal rights information for women in India

Key numbers to always have ready:
- Police: 100
- Women Helpline: 1091  
- National Emergency: 112
- Bengaluru Police Control: 080-22942222
- Cyber Crime: 1930
- iCall counselling: 9152987821

Keep responses SHORT (under 100 words) and ACTION-ORIENTED.
If user seems in immediate danger, IMMEDIATELY say: "Press the red SOS button NOW."
Never panic the user. Be calm, clear, and caring.
Respond in English or Hindi based on user's message.`;

// POST /api/chatbot
router.post('/', async (req: Request, res: Response) => {
  const { message, history = [] } = req.body;

  if (!message?.trim()) {
    return res.status(400).json({ error: 'Message required' });
  }

  try {
    const messages = [
      ...history.map((h: any) => ({
        role: h.isUser ? 'user' : 'assistant' as const,
        content: h.text,
      })),
      { role: 'user' as const, content: message },
    ];

    const response = await anthropic.messages.create({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 256,
      system: SYSTEM_PROMPT,
      messages,
    });

    const reply = response.content[0].type === 'text'
      ? response.content[0].text
      : 'I\'m here to help. If you\'re in danger, press the SOS button.';

    res.json({ reply });
  } catch (err) {
    console.error('Chatbot error:', err);
    // Fallback response even if API fails
    res.json({
      reply: 'I\'m having connectivity issues. If you\'re in danger, press the red SOS button immediately or call 112.',
    });
  }
});

export { router as chatbotRouter };
