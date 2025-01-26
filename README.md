# Personal

Static page generator from Markdown to html with 0 dependencies.

This is a personal project and it not intended to support every edge case, I patch as I need them.

This project has different parts
- An HTTP Server that just accepts connections and server GET requests
- File caching at startup 
- Prevention of FS executions while requesting Paths
- Markdown to HTML parser

