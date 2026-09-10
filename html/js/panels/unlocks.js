const TINT_SWATCH = {
    0: '#b9b2a4',
    1: '#3f7a35',
    2: '#c8a022',
    3: '#d8508f',
    4: '#6b6b4a',
    5: '#2f5fa8',
    6: '#d1701f',
    7: '#c9ccd2',
};

function myCosmetics() {
    const profile = (APP.boot && APP.boot.profile) || {};
    return profile.cosmetics || { tint: 0, kit: 'none' };
}

async function pickCosmetic(patch) {
    const next = { ...myCosmetics(), ...patch };

    const result = await nui('setCosmetics', { cosmetics: next });
    if (!reportResult(result, 'Saved')) return;

    if (result.profile) APP.boot.profile = result.profile;
    renderLevel();
    renderUnlocks();
}

function renderUnlocks() {
    const content = document.getElementById('content');
    const catalogue = (APP.boot && APP.boot.cosmetics) || null;

    if (!catalogue) {
        content.innerHTML = '<div class="empty"><strong>Cosmetics are off</strong>Turn them on with Config.Cosmetics.enabled.</div>';
        return;
    }

    const chosen = myCosmetics();
    const profile = APP.boot.profile || {};

    const lockedTints = catalogue.tints.filter(t => !t.unlocked).length;
    const lockedKits = catalogue.kits.filter(k => !k.unlocked).length;

    document.getElementById('topbar-actions').innerHTML =
        `<span class="tag">${lockedTints + lockedKits} still locked</span>`;

    content.innerHTML = `
        <div class="section-title">Kits</div>
        <div class="grid auto">
            ${catalogue.kits.map(kit => `
                <div class="weapon-card ${chosen.kit === kit.id ? 'selected' : ''} ${kit.unlocked ? '' : 'locked'}"
                     ${kit.unlocked ? `data-kit="${esc(kit.id)}"` : ''}>
                    <div class="grow">
                        <div class="weapon-name">${esc(kit.label)}</div>
                        <div class="weapon-cat">${kit.pieces > 0 ? `${kit.pieces} pieces` : 'no change'}</div>
                    </div>
                    ${kit.unlocked
                        ? (chosen.kit === kit.id ? '<span class="tag">worn</span>' : '')
                        : `<span class="tag muted">${esc(kit.requires || 'locked')}</span>`}
                </div>`).join('')}
        </div>

        <div class="section-title">Weapon tints</div>
        <div class="grid auto">
            ${catalogue.tints.map(tint => `
                <div class="weapon-card ${chosen.tint === tint.id ? 'selected' : ''} ${tint.unlocked ? '' : 'locked'}"
                     ${tint.unlocked ? `data-tint="${tint.id}"` : ''}>
                    <span style="width:22px;height:22px;flex:0 0 22px;border:2px solid var(--ink);background:${TINT_SWATCH[tint.id] || '#999'}"></span>
                    <div class="grow">
                        <div class="weapon-name">${esc(tint.label)}</div>
                        <div class="weapon-cat">${tint.unlocked ? 'unlocked' : esc(tint.requires || 'locked')}</div>
                    </div>
                    ${chosen.tint === tint.id ? '<span class="tag">on</span>' : ''}
                </div>`).join('')}
        </div>

        <div class="card" style="margin-top:20px">
            <div class="card-head"><div class="card-title">How you earn these</div></div>
            <div class="field-hint" style="margin:0">
                Kits and tints unlock by level or by total wins. You are level
                <strong>${profile.level || 1}</strong> with <strong>${profile.wins || 0}</strong> win${(profile.wins || 0) === 1 ? '' : 's'}.
                Your kit goes on when a match starts and comes off when it ends — your own clothes are never changed.
            </div>
        </div>`;

    content.querySelectorAll('[data-kit]').forEach(el => {
        el.addEventListener('click', () => pickCosmetic({ kit: el.dataset.kit }));
    });

    content.querySelectorAll('[data-tint]').forEach(el => {
        el.addEventListener('click', () => pickCosmetic({ tint: Number(el.dataset.tint) }));
    });
}
