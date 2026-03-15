<script lang="ts">
    import { onMount } from 'svelte';

    export let direction: 'horizontal' | 'vertical' = 'horizontal';
    export let initialSplit = 50; // percentage for first pane

    let container: HTMLDivElement;
    let splitPercent = initialSplit;
    let isDragging = false;

    function onMouseDown(e: MouseEvent) {
        e.preventDefault();
        isDragging = true;

        const onMouseMove = (e: MouseEvent) => {
            if (!isDragging || !container) return;
            const rect = container.getBoundingClientRect();
            if (direction === 'horizontal') {
                splitPercent = ((e.clientX - rect.left) / rect.width) * 100;
            } else {
                splitPercent = ((e.clientY - rect.top) / rect.height) * 100;
            }
            splitPercent = Math.max(10, Math.min(90, splitPercent));
        };

        const onMouseUp = () => {
            isDragging = false;
            window.removeEventListener('mousemove', onMouseMove);
            window.removeEventListener('mouseup', onMouseUp);
        };

        window.addEventListener('mousemove', onMouseMove);
        window.addEventListener('mouseup', onMouseUp);
    }
</script>

<div
    class="split-pane {direction}"
    bind:this={container}
>
    <div class="pane first" style="{direction === 'horizontal' ? 'width' : 'height'}: {splitPercent}%">
        <slot name="first" />
    </div>
    <div
        class="divider {direction}"
        on:mousedown={onMouseDown}
        class:dragging={isDragging}
    ></div>
    <div class="pane second" style="{direction === 'horizontal' ? 'width' : 'height'}: {100 - splitPercent}%">
        <slot name="second" />
    </div>
</div>

<style>
    .split-pane {
        display: flex;
        width: 100%;
        height: 100%;
        overflow: hidden;
    }
    .split-pane.vertical {
        flex-direction: column;
    }

    .pane {
        overflow: hidden;
        position: relative;
    }

    .divider {
        flex-shrink: 0;
        background: var(--border);
        transition: background 0.15s;
    }
    .divider.horizontal {
        width: 2px;
        cursor: col-resize;
    }
    .divider.vertical {
        height: 2px;
        cursor: row-resize;
    }
    .divider:hover, .divider.dragging {
        background: var(--blue);
    }
</style>
