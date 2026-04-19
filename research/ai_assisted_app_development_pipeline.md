## Link:
https://youtu.be/LvsgCdWss4I?si=LC1rN2Gu4THBhnft

## Transcript
00:00:00
I built over 14 different apps over the past four years at this point and probably for 99% of those apps I was the only developer. I was a solo developer building the app by myself. Now over the past four years the coding and app building landscape has changed dramatically primarily with the introduction of LLMs and AI powered coding and I you know you know not to flex or anything but I do consider myself a pretty early adopter for all things AI coding related. I was pretty early with GitHub Copilot, pretty early

00:00:28
with Cursor, all these AI powered code editors. And with that in mind, over the past year, I do feel like I've found a good workflow that works for me as a solo developer to help me build a lot of apps really quickly. And that's what I want to talk about in this video. I want to talk about my AI powered solo dev workflow to build apps really quickly. So, let's get started. Now, for this video, I do use Cursor as my AI code editor of choice, but I'm not sponsored by them. I have zero affiliation with

00:00:55
them whatsoever. It's just what I use. But any talks about like the workflow I give in this video should work with any AI powered code editor of your choice. Now I have a whole separate video where I go about my entire process of how I find ideas of apps to build and you should definitely check that video out yourself. So the first step of the process, so let's say that you have an app that you want to build. The very first part of the process is designing the application and figuring out the UI

00:01:18
layer of it. I really don't focus too hard on the database, the schema of it all. First step is very minimal coding. It's all UI explorations because at this point in 2025, at the time of filming this video, I do believe that the bar of quality for apps have really gotten a lot higher. And typically one of the easiest signs of quality is the UI and the UX that the user goes through while interacting with your apps. And then once I have the UI laid out, that's when I start thinking about the whole backend

00:01:43
process. So with the app that I want to build, I immediately start looking for other competitors in the space. Now, for myself particularly, I only build apps that already have proven market validation that have proven track record of people willing to pay for that product. I have a whole video where I go into my entire like app building ideology in a video right here. I believe it's called how I build apps solo that actually make money. Something like that. Check that video out. I go much more in depth. But the TLDDR

00:02:07
summary is the fact that I only build apps that already exist out there in the world and have proven business models. So because I do that, I immediately start going at all the other competitors and I sign up for their applications and see the various UI inspirations and the UI flows that they're going through. And then I just start creating this mental model in my head about what I like and what I didn't like. And then I also love taking a bunch of screenshots of the various applications and dumping them

00:02:30
into like some folder on my laptop because I use these screenshots later on in my AI code editing process. I had a bad habit previously where I would not design the application at all and instead I would just go straight into building. But often times that wasn't really good because I find myself like building some initial iteration of the UI realizing, oh no, this looks really bad. Then I would go back and try to redesign it multiple times over and over again. So now I really like to spend

00:02:53
that extra effort in the beginning to kind of nail the UI a bit more. And I'm not a good designer at all. I have a pretty bad eye for design if I'm really being honest. And I am ass at Figma. I'm so garbage at Figma. I've tried to learn how to use it multiple times, but I'm just so slow at it and it just feels so inefficient. But now with the rise of AI coding, there's also AI powered design. So I use a tool called magicpatterns.com. It is an AI powered design tool, kind of like an AI powered

00:03:16
Figma almost, but it spits everything out in code. It's an awesome AI powered prototyping tool and I have been using lately to kind of create the general UI mockups of my app. It's all with natural language where I tell it to build something. I can ask it for edits just by chatting with natural language. Great product, 10 out of 10. And also one of my good friends from college is actually the founders as well. This is not sponsored. He did not pay me at all to plug this. I He doesn't even know I'm

00:03:38
talking about this product in this video. I'm just a big fan and I pay for the product myself. So then within Magic Patterns, you can also take all of those screenshots that you took of the competitors as well as through Mobin and dump them into Magic Patterns to figure out what exactly your UI flow is going to look like. So that's step one. And I spent a pretty decent amount of time figuring out the design process of that. And then once I figured out the UI that I liked, that's when I started moving

00:03:59
over to actually planning out what the back-end data structures are going to look like. And this is when I open up my AI powered code editor. Now with Cursor, and I'm pretty sure with all of the other AI powered code editors as well, you can add MCPS into your code editor model context protocol to provide the LLM with greater access to various other tools that you are building with. Now for my personal text stack, I use Nex.js with Superbase in the background. I use Superbase for literally everything in my

00:04:25
app. app. I use it for authentication, storage, database, every now and then functions as well, like edge functions, web hooks, all that stuff. I've been a longtime Superbase user for probably the past year or two, and it has been a staple in all of the apps that I'm building. And the best part about this is that Superbase actually has an MCP that you could plug in to your AI code editor of choice, mine being cursor like I said before. And by doing this, you give your AI code editor access to

00:04:48
seeing what does your superbase database schema look like? What is the structure of how your Postgress tables are laid out? So now I connect my Superbase MCP into my cursor editor. And then from here, this is when I start figuring out kind of the system design of what's going on. So now with the Superbase MCP plugged into my cursor code editor, this is when I start figuring out the whole backend process of what the system design is going to look like. What are the database tables looking like in the

00:05:11
back end? And LLMs are really good at system design. At this point, I'm usually pretty good that I know the general flow of like, all right, well, I'm going to create this users table, and then this users table is going to link to this table, blah blah blah blah blah. But every now and then I have to go out and build a brand new feature that is net new that I have a little bit more trouble with in terms of figuring out what the system design is going to look like. It's particularly what the

00:05:32
database table design is going to look like. And that is when I start using the LLM chat function within cursor to figure out what that database schema design is going to look like. I describe the feature. I then tell cursor hey this is what I want to build. So then from here I open up the chat window within cursor and I connect it to my superbase MCP and I start chatting back and forth about what should the database design look like. But I also use cursor to help me generate the system design of the

00:05:54
architecture of my application as well and it does a really great job of it. So as you can see right here, cursor not only helps me with the design process of the UI and the UX, but it also helps me with the system design, the database design of it all. And when using cursor, I am a big proponent of using a ton of cursor rules. I think luckily like a week ago, cursor just released a brand new tool that actually autogenerates these cursor rules for you with just one simple command. And generating cursor

00:06:17
rules is really convenient because it provides cursor with the additional context about what exactly your application is, the text stack that you're building with, the general product structure, your coding conventions, the coding tendencies. Very, very useful if you're not using cursor rules in your code editor. Highly recommend that you do that. All right, so now I chat back and forth. I figured out what the system design, what the backend architecture is going to look like. And now this is when I actually

00:06:37
start building. Here are some of my general strategies that I use to use AI to help me build out my applications, which are typically written in Nex.js JS with once again the superbase powering the authentication back end all that stuff as well. Whenever I build any feature using an LLM to help me code the number one thing I add to every single one of my prompts is at the very end of my prompt being do not make any changes until you have 95% confidence that you know what to build. Ask me follow-up

00:07:00
questions until you have that confidence. This tiny little sentence that I add at the very end has vastly improved the performance of the code that the LLM writes for me. Because if you don't add that, sometimes the LLM gets a little too cocky. They're like, "Yeah, bro. I can do this." It's like, "Whoa, chill." like you don't know what you're doing and often times they don't and they write way too much spaghetti code and they don't really know what

00:07:18
you're asking for. So I do find that adding that little prompt at the end of like hey ask me any clarifying questions that you have until you're really really confident you know what to build it's helped out a lot. Highly recommend that you add this to all of your prompts as you start coding with LLM. Another general tip that I typically do is don't ask it to do too much. I think if you ask it to build way too much in one prompt gets a little confusing. Instead, if you have a gigantic feature that you

00:07:39
want to build, just ask it to build one thing one step at a time, like one UI block, one function, one API route, one step at a time, and just keep everything within that one gigantic chat context. Kind of progressing into my next tip is that I do my very best to not make new chats as much as possible. Whenever I'm trying to build a particular feature, do not make a brand new chat. I try to do as much work in that same chat context because the longer and more details you provide throughout that chat, the more

00:08:06
context it's able to provide to the LLM and the more context that it provides, I do find that it performs better and it knows more about what exactly you're trying to build and the errors that it's made in the past. So, I do my very best to keep everything that I possibly can in the same chat history, in the same chat conversation without starting a new one. Because when you start a new one, you lose context and you're kind of starting from ground zero again. At this point, if you're following my workflow

00:08:29
exactly, I have both the screenshots of various apps that I like, the UI components of various apps and competitors that I like, and I also have the actual designs with real code from a magic patterns as well. So, from here, what I do is within magic patterns, they have actually the actual code that you can copy and paste just directly into your application. Very, very useful for that. My typical workflow is I go through Magic Patterns. I go through all of my UX designs, my UI designs, and then from here, I pick out all the parts

00:08:54
that I like, and I copy that code just directly into my AI code editor. It's written it all out for me. And then from there, if I want to do any further refinements because, you know, sometimes things could look different from the AI code editor versus the actual designs. You know, maybe you want to switch some things up in that moment. That's when I start importing in all of the various screenshots and pictures that I took earlier on and I dump them into my code editor as well and say, "Hey, make any

00:09:17
changes to make it look more like this or change that particular code component right there." I always attach a ton of images into my AI code editor every single time. And I think it provides them with more context of what's exactly going on. Especially with UI bugs, if I see that like a code editor tries to build something out, but it looks a little weird, I always take a screenshot and I upload it into my chat conversation being like, "Hey, this is what it looks like right now. It doesn't

00:09:38
look right. Please fix it." I personally feel like I get better results every single time I attach an image when I try to fix a UI bug compared to just asking the LLM to fix my code without any context of what it actually looks like. And I basically rinse and repeat this entire process every single time for every new feature that I build. I see what competitor is doing. I see what I like. Dump them into my AI design tool, Magic Patterns. Figure out what UX I want to move forward with. Then once I

00:10:01
have the UI figured out, then I figure out what the backend implementation is going to look like, what the new database tables are going to look like, what's the architecture going to look like. And I do that by using my Superbase MCP connected to Cursor to chat back and forth to figure out the correct system design for this. And then I put it all together in the final stages of implementing those backend changes and continually fixing bugs by taking screenshots of the UI bug, uploading it into my chat, continually

00:10:22
iterating that way and keeping everything within the same chat window, same chat context. And then I further iterate on all the front-end designs and the front-end work by taking screenshots of the UX bugs, dumping them into one gigantic chat context, minimizing the number of new chats that I build, and continually iterating back and forth again and again until it all works out in the end. So that is my AI enabled solo dev process. Hope you enjoy it. Hope you found it useful. Let me know if you have any questions or thoughts or

00:10:45
opinions in the comments down below. But that is about it for today's video. Thanks so much for watching and I'll see you in the next one.


## Summary
Here’s a clear bullet-point summary of the solo developer’s **AI-powered workflow** from the document:

- **Solo dev context**  
  - Built 14+ apps over 4 years, mostly solo.  
  - Early adopter of AI coding tools (GitHub Copilot, Cursor).  
  - Uses AI to accelerate app development.

- **Design phase**  
  - Focus first on **UI/UX quality** (higher bar in 2025).  
  - Collect competitor screenshots for inspiration.  
  - Uses **MagicPatterns.com** (AI-powered design tool) for prototyping.  
  - Avoids Figma due to inefficiency; prefers natural language-driven design.

- **Backend planning**  
  - After UI, plan backend data structures.  
  - Tech stack: **Next.js + Supabase** (auth, storage, DB, functions).  
  - Supabase MCP integrated into Cursor for schema/system design.  
  - LLMs assist with database schema and architecture design.

- **Cursor rules**  
  - Provides context about app, stack, coding conventions.  
  - Recently automated rule generation improves efficiency.  
  - Helps LLM understand product structure and coding tendencies.

- **Coding strategies**  
  - Add prompt suffix: *“Do not make changes until 95% confident. Ask clarifying questions first.”*  
  - Break large features into **small steps** (UI block, function, API route).  
  - Keep work in **one chat context** for better continuity and error tracking.  
  - Attach screenshots/images to fix UI bugs (better results than text-only prompts).

- **Iterative workflow**  
  - Cycle: competitor research → MagicPatterns design → Supabase schema planning → Cursor-assisted coding.  
  - Constant iteration with screenshots and chat context.  
  - Minimize new chats to preserve context.  
  - Rinse and repeat for each new feature.

- **Key takeaway**  
  - Workflow blends **AI design tools**, **AI code editors**, and **MCP integrations**.  
  - Emphasis on **UI quality**, **system design clarity**, and **iterative refinement**.  
  - Enables rapid solo app development with fewer mistakes and faster iteration.  

This process is essentially a **repeatable AI-enabled pipeline**: design → backend planning → coding → iteration. 
