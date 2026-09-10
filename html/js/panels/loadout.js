let loadoutSlot = 'primary';

function weaponLabel(name) {
    if (!name) return '';
    const entry = (APP.boot.weapons || []).find(w => w.name === name);
    if (entry) return entry.label;
    return String(name).replace(/^WEAPON_/, '').replace(/_/g, ' ').toLowerCase();
}

function currentLoadout() {
    if (APP.loadout) return APP.loadout;

    const me = myEntry();

    if (me && me.loadout) {
        APP.loadout = { ...me.loadout };
    } else {
        const preset = (APP.boot.loadouts || [])[0];
        APP.loadout = preset ? { ...preset.data } : {};
    }

    return APP.loadout;
}

function slotsAvailable() {
    const slots = (APP.boot.loadout && APP.boot.loadout.slots) || {};
    return ['primary', 'secondary', 'melee'].filter(slot => slots[slot]);
}

async function pushLoadout() {
    const result = await nui('setLoadout', { loadout: currentLoadout() });
    if (result && result.ok && result.loadout) APP.loadout = result.loadout;
    renderLoadout();
}

function savePresetModal() {
    const presets = APP.boot.loadout.presets || 0;
    if (presets <= 0) return;

    const options = [];
    for (let i = 1; i <= presets; i += 1) options.push({ value: i, label: `Slot ${i}` });

    modal('Save loadout', `
        ${field('Preset slot', selectInput('preset-slot', options, 1))}
        ${field('Name', textInput('preset-label', '', 'Long range'))}
    `, async () => {
        const result = await nui('saveLoadoutPreset', {
            slot: numberValue('preset-slot', 1),
            label: value('preset-label'),
            loadout: currentLoadout(),
        });

        if (!reportResult(result, 'Preset saved')) return false;

        APP.boot.loadouts = result.loadouts || APP.boot.loadouts;
        renderLoadout();
    }, 'Save');
}

function renderLoadout() {
    const content = document.getElementById('content');
    const boot = APP.boot;
    const loadout = currentLoadout();
    const level = (boot.profile && boot.profile.level) || 1;
    const slots = slotsAvailable();

    if (!slots.includes(loadoutSlot)) loadoutSlot = slots[0] || 'primary';

    document.getElementById('topbar-actions').innerHTML = `
        ${boot.loadout.presets > 0 ? '<button class="btn btn-sm" id="btn-save-preset">Save preset</button>' : ''}
        ${inLobby() ? '<button class="btn btn-sm btn-primary" id="btn-back-lobby">Back to lobby</button>' : ''}`;

    const weapons = (boot.weapons || []).filter(w => w.slot === loadoutSlot);
    const categories = [...new Set(weapons.map(w => w.category))];

    content.innerHTML = `
        <div class="row" style="align-items:flex-start;gap:16px">
            <div class="grow">
                <div class="slot-tabs">
                    ${slots.map(slot => `
                        <button class="slot-tab ${loadoutSlot === slot ? 'active' : ''}" data-slot="${slot}">
                            ${slot.charAt(0).toUpperCase() + slot.slice(1)}
                            ${loadout[slot] ? ` — ${esc(weaponLabel(loadout[slot]))}` : ''}
                        </button>`).join('')}
                </div>

                ${categories.map(category => {
                    const list = weapons.filter(w => w.category === category);
                    return `
                        <div class="section-title">${esc(list[0].categoryLabel || category)}</div>
                        <div class="grid auto">
                            ${list.map(weapon => {
                                const locked = weapon.unlock > level;
                                const selected = loadout[loadoutSlot] === weapon.name;
                                return `
                                    <div class="weapon-card ${selected ? 'selected' : ''} ${locked ? 'locked' : ''}" ${locked ? '' : `data-weapon="${esc(weapon.name)}"`}>
                                        <div class="grow">
                                            <div class="weapon-name">${esc(weapon.label)}</div>
                                            <div class="weapon-cat">${esc(weapon.categoryLabel || weapon.category)}</div>
                                        </div>
                                        ${locked ? `<span class="tag muted">lvl ${weapon.unlock}</span>` : ''}
                                        ${weapon.paint ? '<span class="tag accent">paint</span>' : ''}
                                    </div>`;
                            }).join('')}
                        </div>`;
                }).join('')}
            </div>

            <div class="col" style="width:300px;flex:0 0 300px">
                <div class="card">
                    <div class="card-head"><div class="card-title">Carrying</div></div>
                    <div class="list">
                        ${slots.map(slot => `
                            <div class="list-row" style="padding:9px 0">
                                <div class="list-main">
                                    <div class="list-sub">${slot}</div>
                                    <div class="list-name" style="font-size:12.5px">${esc(weaponLabel(loadout[slot]) || 'Nothing')}</div>
                                </div>
                                ${loadout[slot] ? `<button class="btn btn-sm btn-ghost" data-clear="${slot}">Clear</button>` : ''}
                            </div>`).join('')}
                    </div>
                </div>

                ${(boot.loadouts || []).length ? `
                    <div class="card">
                        <div class="card-head"><div class="card-title">Presets</div></div>
                        <div class="list">
                            ${boot.loadouts.map(preset => `
                                <div class="list-row" style="padding:9px 0">
                                    <div class="list-main">
                                        <div class="list-name" style="font-size:12.5px">${esc(preset.label || `Slot ${preset.slot}`)}</div>
                                        <div class="list-sub">${esc(Object.values(preset.data || {}).filter(Boolean).map(weaponLabel).join(' · '))}</div>
                                    </div>
                                    <button class="btn btn-sm" data-preset="${preset.slot}">Use</button>
                                </div>`).join('')}
                        </div>
                    </div>` : ''}

                <div class="card">
                    <div class="card-head"><div class="card-title">Gun Game ladder</div></div>
                    <div class="row wrap" style="gap:5px">
                        ${(boot.ladder || []).map((rung, index) =>
                            `<span class="tag ${index === 0 ? 'accent' : 'muted'}">${index + 1}. ${esc(rung.label)}</span>`).join('')}
                    </div>
                    <div class="field-hint">Gun Game and One In The Chamber hand out their own weapons, so your loadout is ignored in those modes.</div>
                </div>
            </div>
        </div>`;

    content.querySelectorAll('[data-slot]').forEach(el => {
        el.addEventListener('click', () => {
            loadoutSlot = el.dataset.slot;
            renderLoadout();
        });
    });

    content.querySelectorAll('[data-weapon]').forEach(el => {
        el.addEventListener('click', () => {
            loadout[loadoutSlot] = el.dataset.weapon;
            pushLoadout();
        });
    });

    content.querySelectorAll('[data-clear]').forEach(el => {
        el.addEventListener('click', () => {
            delete loadout[el.dataset.clear];
            pushLoadout();
        });
    });

    content.querySelectorAll('[data-preset]').forEach(el => {
        el.addEventListener('click', () => {
            const preset = (boot.loadouts || []).find(p => String(p.slot) === el.dataset.preset);
            if (!preset) return;

            APP.loadout = { ...preset.data };
            pushLoadout();
        });
    });

    const savePreset = document.getElementById('btn-save-preset');
    if (savePreset) savePreset.addEventListener('click', savePresetModal);

    const back = document.getElementById('btn-back-lobby');
    if (back) back.addEventListener('click', () => setTab('lobby', true));
}
