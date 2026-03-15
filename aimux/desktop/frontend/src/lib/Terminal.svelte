<script lang="ts">
    import { onMount, onDestroy } from 'svelte';
    import { Terminal } from 'xterm';
    import { FitAddon } from '@xterm/addon-fit';
    import { WebLinksAddon } from '@xterm/addon-web-links';

    export let sessionId: string;
    export let wsPort: number;

    let terminalEl: HTMLDivElement;
    let terminal: Terminal;
    let fitAddon: FitAddon;
    let ws: WebSocket;
    let resizeObserver: ResizeObserver;

    onMount(() => {
        terminal = new Terminal({
            theme: {
                background: '#1a1b26',
                foreground: '#c0caf5',
                cursor: '#c0caf5',
                cursorAccent: '#1a1b26',
                selectionBackground: '#283457',
                black: '#15161e',
                red: '#f7768e',
                green: '#9ece6a',
                yellow: '#e0af68',
                blue: '#7aa2f7',
                magenta: '#bb9af7',
                cyan: '#7dcfff',
                white: '#a9b1d6',
                brightBlack: '#414868',
                brightRed: '#f7768e',
                brightGreen: '#9ece6a',
                brightYellow: '#e0af68',
                brightBlue: '#7aa2f7',
                brightMagenta: '#bb9af7',
                brightCyan: '#7dcfff',
                brightWhite: '#c0caf5',
            },
            fontFamily: "'JetBrains Mono', 'Fira Code', 'SF Mono', Menlo, monospace",
            fontSize: 13,
            lineHeight: 1.2,
            cursorBlink: true,
            cursorStyle: 'bar',
            allowTransparency: false,
            scrollback: 10000,
        });

        fitAddon = new FitAddon();
        terminal.loadAddon(fitAddon);
        terminal.loadAddon(new WebLinksAddon());

        terminal.open(terminalEl);
        fitAddon.fit();

        // Connect WebSocket
        connectWS();

        // Handle user input -> WebSocket
        terminal.onData((data) => {
            if (ws && ws.readyState === WebSocket.OPEN) {
                ws.send(new Blob([new TextEncoder().encode(data)]));
            }
        });

        // Handle resize
        terminal.onResize(({ cols, rows }) => {
            if (ws && ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({
                    type: 'resize',
                    data: { cols, rows }
                }));
            }
        });

        // Observe container resize
        resizeObserver = new ResizeObserver(() => {
            fitAddon.fit();
        });
        resizeObserver.observe(terminalEl);
    });

    function connectWS() {
        ws = new WebSocket(`ws://127.0.0.1:${wsPort}/ws/terminal/${sessionId}`);
        ws.binaryType = 'arraybuffer';

        ws.onmessage = (event) => {
            if (event.data instanceof ArrayBuffer) {
                terminal.write(new Uint8Array(event.data));
            } else {
                terminal.write(event.data);
            }
        };

        ws.onclose = () => {
            terminal.write('\r\n\x1b[90m[Session ended]\x1b[0m\r\n');
        };

        ws.onerror = (err) => {
            console.error('WebSocket error:', err);
        };
    }

    onDestroy(() => {
        if (resizeObserver) resizeObserver.disconnect();
        if (ws) ws.close();
        if (terminal) terminal.dispose();
    });
</script>

<div class="terminal-container" bind:this={terminalEl}></div>

<style>
    .terminal-container {
        width: 100%;
        height: 100%;
        overflow: hidden;
    }

    .terminal-container :global(.xterm) {
        padding: 8px;
        height: 100%;
    }
</style>
