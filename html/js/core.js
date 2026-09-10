const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'XS-Paintball';

function esc(value) {
    if (value === null || value === undefined) return '';
    return String(value)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

async function nui(endpoint, payload = {}) {
    try {
        const res = await fetch(`https://${RESOURCE}/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
        });
        return await res.json();
    } catch (e) {
        return null;
    }
}

function clock(seconds) {
    const total = Math.max(0, Math.floor(seconds || 0));
    return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`;
}

function money(amount) {
    return `$${Number(amount || 0).toLocaleString('en-US')}`;
}

function ratio(kills, deaths) {
    if (!deaths) return Number(kills || 0).toFixed(2);
    return (kills / deaths).toFixed(2);
}

const TOAST_ICONS = { info: 'i', success: '✓', error: '✕', warning: '!' };

function toast(title, body = '', type = 'info', duration = 4200) {
    const host = document.getElementById('toast-container');
    if (!host) return;

    const el = document.createElement('div');
    el.className = `toast ${type}`;
    el.innerHTML = `
        <div class="toast-icon">${TOAST_ICONS[type] || 'i'}</div>
        <div class="toast-content">
            <div class="toast-title">${esc(title)}</div>
            ${body ? `<div class="toast-body">${esc(body)}</div>` : ''}
        </div>`;

    host.appendChild(el);

    setTimeout(() => {
        el.style.transition = 'opacity .3s ease, transform .3s ease';
        el.style.opacity = '0';
        el.style.transform = 'translateX(20px)';
        setTimeout(() => el.remove(), 300);
    }, duration);
}

function reportResult(result, successTitle, successBody) {
    if (result && result.ok) {
        if (successTitle) toast(successTitle, successBody || '', 'success');
        return true;
    }

    if (result && result.cancelled) return false;

    toast('That did not work', (result && result.error) || 'The server refused it.', 'error');
    return false;
}

function closeModal() {
    document.getElementById('modal-root').innerHTML = '';
}

function modal(title, bodyHtml, onConfirm, confirmLabel = 'Save', size = '') {
    const root = document.getElementById('modal-root');
    const readOnly = typeof onConfirm !== 'function';

    root.innerHTML = `
        <div class="modal-backdrop">
            <div class="modal ${size}">
                <div class="modal-header">
                    <div class="modal-title">${esc(title)}</div>
                    <button class="modal-close" data-modal-cancel>&times;</button>
                </div>
                <div class="modal-body">${bodyHtml}</div>
                <div class="modal-footer">
                    ${readOnly ? '' : '<button class="btn btn-ghost" data-modal-cancel>Cancel</button>'}
                    <button class="btn ${readOnly ? 'btn-ghost' : 'btn-primary'}" data-modal-confirm>
                        ${esc(readOnly ? 'Close' : confirmLabel)}
                    </button>
                </div>
            </div>
        </div>`;

    root.querySelectorAll('[data-modal-cancel]').forEach(el => el.addEventListener('click', closeModal));

    root.querySelector('[data-modal-confirm]').addEventListener('click', async (e) => {
        if (readOnly) { closeModal(); return; }

        const btn = e.currentTarget;
        btn.disabled = true;
        const keepOpen = await onConfirm();
        btn.disabled = false;
        if (keepOpen !== false) closeModal();
    });

    const first = root.querySelector('input, textarea, select');
    if (first) first.focus();
}

function confirmDanger(title, message, onConfirm, confirmLabel = 'Delete') {
    const root = document.getElementById('modal-root');

    root.innerHTML = `
        <div class="modal-backdrop">
            <div class="modal">
                <div class="modal-header">
                    <div class="modal-title">${esc(title)}</div>
                    <button class="modal-close" data-modal-cancel>&times;</button>
                </div>
                <div class="modal-body"><div class="field-hint" style="font-size:12.5px">${esc(message)}</div></div>
                <div class="modal-footer">
                    <button class="btn btn-ghost" data-modal-cancel>Cancel</button>
                    <button class="btn btn-danger" data-modal-confirm>${esc(confirmLabel)}</button>
                </div>
            </div>
        </div>`;

    root.querySelectorAll('[data-modal-cancel]').forEach(el => el.addEventListener('click', closeModal));

    root.querySelector('[data-modal-confirm]').addEventListener('click', async () => {
        await onConfirm();
        closeModal();
    });
}

function field(label, inputHtml, hint) {
    return `
        <div class="field">
            <label class="field-label">${esc(label)}</label>
            ${inputHtml}
            ${hint ? `<div class="field-hint">${esc(hint)}</div>` : ''}
        </div>`;
}

function textInput(id, value = '', placeholder = '', type = 'text') {
    return `<input type="${type}" id="${id}" value="${esc(value)}" placeholder="${esc(placeholder)}">`;
}

function selectInput(id, options, selected) {
    const opts = options.map(o => {
        const value = typeof o === 'string' ? o : o.value;
        const label = typeof o === 'string' ? o : o.label;
        return `<option value="${esc(value)}" ${String(value) === String(selected) ? 'selected' : ''}>${esc(label)}</option>`;
    }).join('');

    return `<select id="${id}">${opts}</select>`;
}

function toggleRow(id, label, sub, on) {
    return `
        <div class="toggle ${on ? 'on' : ''}" data-toggle="${id}">
            <div>
                <div class="toggle-label">${esc(label)}</div>
                ${sub ? `<div class="toggle-sub">${esc(sub)}</div>` : ''}
            </div>
            <div class="switch"></div>
        </div>`;
}

function bindToggles(root, onChange) {
    root.querySelectorAll('[data-toggle]').forEach(el => {
        el.addEventListener('click', () => {
            el.classList.toggle('on');
            if (onChange) onChange(el.dataset.toggle, el.classList.contains('on'));
        });
    });
}

function readToggle(root, id) {
    const el = root.querySelector(`[data-toggle="${id}"]`);
    return el ? el.classList.contains('on') : false;
}

function value(id, fallback = '') {
    const el = document.getElementById(id);
    if (!el) return fallback;
    return el.value;
}

function numberValue(id, fallback = 0) {
    const parsed = parseFloat(value(id, ''));
    return Number.isFinite(parsed) ? parsed : fallback;
}

function teamClass(team) {
    return ['red', 'blue', 'green', 'yellow'].includes(team) ? team : 'none';
}
