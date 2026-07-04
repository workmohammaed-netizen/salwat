// فحص ثابت (heuristic) يدوّر على نصوص محتملة الخطورة تُحقن مباشرة داخل innerHTML
// بدون تمريرها على esc()/escJs() أو دوال آمنة معروفة. يشتغل تلقائيًا عبر GitHub Actions
// على كل push، ويفشل البناء لو لقى حالة مشبوهة.
//
// هذا فحص بالنمط (pattern) وليس تحليلاً حقيقيًا لشجرة الكود — قد يعطي نتيجة خاطئة
// نادرًا، فلو ظهر بلاغ غير صحيح أضف الدالة الآمنة الجديدة لقائمة SAFE_WRAPPERS
// أو استثنِ الحقل من RISKY_FIELDS إذا كان مصدره ثابتًا داخل الكود دائمًا.

import { readFileSync } from 'fs';

const FILE = process.argv[2] || 'index.html.html';
const html = readFileSync(FILE, 'utf8');

const SAFE_WRAPPERS = [
  'esc(', 'escJs(', 'fmtN(', 'pctBar(', 'statusBadgeHtml(', 'payFmt(',
  'fmtArDate(', 'isoToDMY(', 'toLocaleString(', 'toLocaleDateString(',
];
const RISKY_FIELDS = [
  'note', 'notes', 'reason', 'name', 'contact', 'details', 'email',
  'hotel', 'client', 'sender', 'receiver', 'axis', 'point', 'carrier', 'location',
];

function isSafe(expr) {
  const trimmed = expr.trim();
  // نعتبره آمن لو كل حقل خطر مذكور بالتعبير واقع فعليًا داخل قوس دالة تعقيم آمنة
  // (نتحقق بشكل مبسّط: هل يوجد استدعاء دالة آمنة بالتعبير أصلاً يغلّف نفس الجزء؟)
  if (SAFE_WRAPPERS.some(fn => trimmed.includes(fn))) return true;
  // تعبير رقمي أو منطقي بحت أو ثابت نصي — ما فيه خطر
  if (/^[\d.+\-*/%()\s?:'"<>=!&|]+$/.test(trimmed) && !RISKY_FIELDS.some(f => trimmed.includes(f))) return true;
  return false;
}

// يحدد نهاية القالب النصي (template literal) الفعلية بدل نافذة ثابتة بعدد الأحرف،
// عشان ما نمتد بالخطأ لأسطر لاحقة غير مرتبطة (مثل textContent) بعد innerHTML
function extractTemplateLiteral(text, fromIndex) {
  const backtickStart = text.indexOf('`', fromIndex);
  if (backtickStart === -1 || backtickStart - fromIndex > 20) return null; // ما فيه backtick قريب = مو نمط متوقّع، تجاهل
  let i = backtickStart + 1;
  let braceDepth = 0;
  while (i < text.length) {
    const ch = text[i];
    if (ch === '\\') { i += 2; continue; }
    if (braceDepth === 0 && ch === '`') return text.slice(backtickStart, i + 1);
    if (ch === '$' && text[i+1] === '{') { braceDepth++; i += 2; continue; }
    if (braceDepth > 0 && ch === '{') { braceDepth++; i++; continue; }
    if (braceDepth > 0 && ch === '}') { braceDepth--; i++; continue; }
    i++;
  }
  return text.slice(backtickStart); // ما لقينا إغلاق — ناخذ الباقي (نادر)
}

let issues = [];
const innerHtmlRegex = /\.innerHTML\s*[+]?=\s*/g;
let m;
while ((m = innerHtmlRegex.exec(html))) {
  const blockStart = m.index;
  const template = extractTemplateLiteral(html, blockStart);
  if (!template) continue;
  const interpRegex = /\$\{([^{}]*)\}/g;
  let im;
  while ((im = interpRegex.exec(template))) {
    const expr = im[1];
    const touchesRiskyField = RISKY_FIELDS.some(f => new RegExp(`\\.${f}\\b`).test(expr));
    if (touchesRiskyField && !isSafe(expr)) {
      const absoluteIndex = html.indexOf(template, blockStart) + im.index;
      const lineNum = html.slice(0, absoluteIndex).split('\n').length;
      issues.push({ line: lineNum, expr: expr.trim() });
    }
  }
}

// إزالة التكرارات (نفس التعبير بنفس السطر ممكن يُكتشف أكثر من مرة بسبب تداخل النوافذ)
const seen = new Set();
issues = issues.filter(i => {
  const key = i.line + '|' + i.expr;
  if (seen.has(key)) return false;
  seen.add(key);
  return true;
});

if (issues.length) {
  console.error(`✗ لقيت ${issues.length} موضع محتمل الخطورة (نص غير معقّم داخل innerHTML):`);
  issues.forEach(i => console.error(`  سطر ${i.line}: \${${i.expr}}`));
  console.error('\nلو هذي حالة آمنة فعلاً (مصدرها ثابت بالكود)، عدّل scripts/check-xss.mjs وأضفها للاستثناءات.');
  process.exit(1);
} else {
  console.log('✓ ما لقيت أي حقن نص محتمل الخطورة بدون تعقيم.');
}
