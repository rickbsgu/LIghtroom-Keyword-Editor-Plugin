# LightRoom Keyword Editor Plugin - AI Experience

I wasn't really interested in learning Lua (_Lightroom's_ SDK implementation language) or the _Lightroom_ SDK, since they're both pretty niche technolgies and I don't like writing platform specific stuff. So I thought, 'Hey, this is a good job for an AI agent.  Let _it_ do the work.'

I felt optimistically that, because it was a small project and limited in requirements, it should be something that an agent could get its cyber arms around.

## The Start, the Abandonment

As a software developer, my development platform of choice is _VSCode_.  _Github Copilot_ is integrated into _VCSCode_ So, that seemed to be the logical agent of choice.

I described what I wanted in a detailed spec (see spec/MainSpec.md) and pointed the agent to that, to begin.

It provided a good scaffolding and prototype.

However, as with any software project (that I've ever been involved in, anyway), the spec didn't anticipate operational deficiencies that needed to be addressed.  This led to spec changes and further directions to the AI.

As we went further and further into this process of iteratively identifying issues, modifying the spec, and implementing fixes, the AI got further and further out of whack.  The sessions eventually devolved to circular bugs and fixes.

Eventually I had to give up on the AI agent and dig into it on my own.

### AI Nigglies

The AI produced a _lot_ of code &mdash; a lot of duplications and unnecessary branches with ultimately dead code as it explored different avenues to fix the bugs and unanticipated changes that cropped up.

The first order of business was to hack out all of the fat and trim the codebase down to it's essential bits, then re-architect the remaining into a cohesive structure that could be maintained.

I didn't give up on the AI completely &mdash; during this process, I used it to explain areas of code I didn't understand (remembering I was still learning LUA and the SDK), and to verify blocks that I had coded for affirmation or correction.

### AI Conclusion

Firstly, I've been using the Co-Pilot AI at it's basic level.  The agents get better at higher levels (= more expensive levels).   Possibly with a higher level, it might have done better.

Also, I was using it at prompt level, relying on the agent's available resources.  While I did write a quite detailed spec, I didn't provide a context that might have directed the agent to more sources, or specify my preferences.

Too, I think part of the issue is that Lua is somewhat of a niche language (at least from my perspective, coming from C/C++ , and there isn't a lot of information available on it to the agent &mdash; certainly not as much as other less niche languages like python or javascript or C++ (or ...). Combined with the fact that _Lightroom's_ SDK is also quite niche meant that the agent was floundering a bit.

That said, it did provide a good basic scaffolding that I could draw on, and, perhaps the most useful aspect: it gave me a head start on learning Lua and the _Lightroom_ SDK.

In that sense, it was extremely helpful as a learning aid.

### Use AI Again?

Absolutely.  The models get better with each iteration (which happens almost weekly, any more). It did give me a good basis to start.

Would I trust it completely?

Not yet.  While it starts off well, it can get off in the weeds, eventually.  You have to be able to recognize that when it happens.

 That's where an experienced developer makes a difference, I think &mdash; without recognizing it's gone astray, you can get into an endless series of prompts that result in circular bugs and fixes.  And it takes an experienced eye to recognize an architectural mess and reduce it to a more comprehensible implementation.

And, as I mentioned earlier, I do think it's invaluable as a learning and even troubleshooting aid, as long as the scope isn't too large.  The reality is that API's and implementations get more and more complicated and require intense study of reams and reams of often obfuscated documentation.  The AI has access to all of that and can bring it what you need to the fore instantly, usually in clearer terms. 

That said, you'll get better results if you ask, "Why is this statement throwing an error," or "Is this block of code syntactically correct?", rather than, "Why is my program not working like I want?"