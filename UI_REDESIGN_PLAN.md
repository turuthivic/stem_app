# Stem Mixer UI Redesign Plan

Progressive improvements to transform the stem separation detail page into a polished, professional audio mixer interface.

## Phase 1: Quick Polish (Layout & Structure) - DONE
- [x] Group file info and controls into a clean card layout
- [x] Consolidate duplicate download buttons into single section
- [x] Fix floating delete button - moved to header
- [x] Improve stem button row with consistent sizing and spacing
- [x] Add proper visual hierarchy with section headers
- [x] Fix checkbox positioning - clear row layout with checkboxes on left

## Phase 2: Volume Sliders - DONE
- [x] Add horizontal volume slider to each stem track
- [x] Create a mixer-style row layout: checkbox | stem name | slider | volume % | play
- [x] Update stem_mixer_controller.js to support gain control via Web Audio API
- [x] Persist volume levels during playback session
- [x] Real-time volume control while playing

## Phase 3: Full Visual Redesign - DONE
- [x] Implement dark theme (standard for audio apps) with toggle
- [x] Create card-based sections: File Info | Mixer | Player | Downloads
- [x] Add subtle animations and transitions
- [x] Improve button styling with better hover/active states
- [x] Color-coded stems (purple=vocals, orange=drums, blue=bass, emerald=other)
- [x] Polish the Plyr player for dark mode

## Phase 4: Waveform Visualization - DONE
- [x] Integrate Wavesurfer.js library via importmap
- [x] Show waveform for currently playing stem
- [x] Add playhead position indicator (cursor)
- [x] Allow seeking via waveform click (built into WaveSurfer)
- [x] Color-matched waveforms per stem type (purple/orange/blue/emerald)
- [x] Play/pause/stop controls for waveform player
- [x] Time display (current time / duration)

---

## Status: ALL PHASES COMPLETE

### Summary of Changes:
1. **Layout**: Card-based design with clear sections (Header, Mixer, Player, Downloads)
2. **Volume Control**: Per-stem sliders with real-time gain adjustment via Web Audio API
3. **Dark Theme**: Full dark mode support with theme toggle, persisted in localStorage
4. **Waveforms**: WaveSurfer.js integration with color-coded stems and seeking
5. **Visual Polish**: Consistent color coding, smooth transitions, better spacing
