---
date: "2025-08-27"
draft: false
title: 'AI showdown: which Brazilian states do not contain the letter "A"?'
tags: ["showdown", "ai", "states"]
---

A question that seems simple, but until recently many generative AIs struggled to answer correctly. How about now?

Expected answer: Sergipe.

| Model                | Mode           | Comment                                                                            | Time                    | Correct  |
| -------------------- | -------------- | ---------------------------------------------------------------------------------: | ----------------------: | :------: |
| GPT-5                | no reasoning   | Mentioned Sergipe and three other states that contain the letter "A".              | Quickly                 |    ❌    |
| GPT-5                | with reasoning | Not tested.                                                                        |                         |    ❓    |
| GPT-5 mini           | no reasoning   | Same response as GPT-5.                                                            | Quickly                 |    ❌    |
| GPT-5 mini           | with reasoning | Thought and answered correctly.                                                    | 13 seconds              |    ✅    |
| Gemini 2.5 Flash     | no reasoning   | Answered that all states contain the letter "A".                                   | Quickly                 |    ❌    |
| Gemini 2.5 Pro       | with reasoning | Thought, searched the internet and still erred, citing Sergipe and Espírito Santo. | Quickly                 |    ❌    |
| Claude Sonnet 4      | no reasoning   | Mentioned three states with the letter "A". Sergipe didn't appear this time.       | Quickly                 |    ❌    |
| Claude Sonnet 4      | with reasoning | Thought and answered correctly.                                                    | 18 seconds              |    ✅    |
| Qwen3-235B-A22B-2507 | no reasoning   | Answered that all states contain the letter "A".                                   | Quickly                 |    ❌    |
| Qwen3-235B-A22B-2507 | with reasoning | Stumbled a bit at the start but managed to arrive at the correct answer.           | 45 seconds              |    ✅    |
| DeepSeek-V3.1        | no reasoning   | Responded with Sergipe and Espírito Santo.                                         | Quickly                 |    ❌    |
| DeepSeek-V3.1        | with reasoning | Thought and answered correctly.                                                    | 1 minute and 10 seconds |    ✅    |

Winner: GPT-5 mini with reasoning.

Conclusion: it’s interesting that only the models with reasoning (with the exception of Gemini 2.5 Pro) managed to reach the correct answer. Conventional generation that tries to predict the correct answer continues to fail badly on this question.
