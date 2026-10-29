/* ============================================================================
   Qradar 콘솔 — 진입점. 셸/라우터는 console-shell.js, 위젯은 console-ui.js,
   역할별 화면은 section-{admin,brand,owner,customer}.js (판정된 역할의 것만 동적 import).
   ========================================================================== */
import { boot } from './console-shell.js';

boot();
