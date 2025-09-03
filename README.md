# luanti-mod-geminti

## Setup
* Add `geminti` to `secure.http_mods` in minetest.conf (NECESSARY)
* Provide your gemini API key into minetest.conf (`geminti.api_key`) (NECESSARY)
* Adjust following settings to meet your needs (optional):

| Setting | Description | Default value |
| ------- | ----------- | ------------- |
| `geminti.name` | Geminti displayed name in the chat | Geminti |
| `geminti.name` | Geminti displayed name prefix | [AI] |
| `geminti.model` | Gemini model to use | gemini-2.5-flash-lite |
| `geminti.prefix` | Geminti chat prefix | ; |
| `geminti.color` | Geminti responses color | #aef |
| `geminti.newlines` | Allow newlines in Geminti responses | false |
| `geminti.strip_urls` | Strip URLs in incoming messages | true |
| `geminti.max_errors` | Maximum errors count before context(chat history) reset | 3 |
| `geminti.system_prompt` | Geminti system prompt | You are in a multiuser chat. Messages follow the pattern '<username> message', where <username> is the sender's name and 'message' is their content. Do not use <username> prefix in your messages. |

## Usage
* Every message sent to the chat stored in the chat history.
* Geminti will reply once player says "Hi", "Hello" or used [`geminti.prefix`] in the beginning of the message
* Admin commands:
  * `/resetgeminti` - clear context(chat history)
  * `/togglegeminti` - toggle Geminti chat history saving and replying
  * `/geminti_chatedit` - open chat history edit formspec
