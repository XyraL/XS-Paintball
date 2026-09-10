async function loadMaps() {
    const result = await nui('adminMaps');
    if (result && result.ok) APP.maps = result.maps || [];
    return APP.maps;
}

function modeChips(modes) {
    const all = (APP.boot.modes || []);
    return all.map(mode => {
        const on = (modes || []).includes(mode.id);
        return `<span class="mode-chip ${on ? 'on' : ''}">${esc(mode.label)}</span>`;
    }).join('');
}

async function openEditor(mapId) {
    const from = APP.tab;

    if (mapId) {
        const result = await nui('mapData', { id: mapId });
        if (!result || !result.ok) {
            reportResult(result);
            return;
        }
        APP.editor = { map: result.map, check: result.check, dirty: false };
    } else {
        APP.editor = { map: null, check: null, dirty: false };
    }

    const opened = await nui('builderOpen', { map: APP.editor.map });
    if (opened && opened.map) APP.editor.map = opened.map;

    // Loading a map takes two round trips. If the user moved on in the
    // meantime, do not drag them into the builder.
    if (APP.tab !== from) {
        nui('builderClose');
        APP.editor = null;
        return;
    }

    setTab('editor', true);
}

function importMapModal() {
    modal('Import a map', `
        ${field('Map file', '<textarea id="import-json" placeholder="Paste the exported map JSON here" rows="10"></textarea>')}
    `, async () => {
        const result = await nui('importMap', { json: value('import-json') });
        if (!reportResult(result, 'Map imported')) return false;

        APP.maps = result.maps || APP.maps;
        renderMaps();
    }, 'Import', 'wide');
}

function exportMapModal(map) {
    nui('exportMap', { id: map.id }).then(result => {
        if (!result || !result.ok) { reportResult(result); return; }

        modal(`Export ${map.name}`, `
            <div class="field-hint" style="margin-bottom:8px">Copy this and keep it somewhere safe. Import it on any server running XS-Paintball.</div>
            <textarea id="export-json" rows="12" readonly>${esc(result.json)}</textarea>
        `, null, 'Close', 'wide');

        const area = document.getElementById('export-json');
        area.focus();
        area.select();
    });
}

function renameMapModal(map) {
    modal(`Rename ${map.name}`, field('Name', textInput('rename-value', map.name)), async () => {
        const result = await nui('renameMap', { id: map.id, name: value('rename-value') });
        if (!reportResult(result, 'Renamed')) return false;

        APP.maps = result.maps || APP.maps;
        renderMaps();
    }, 'Rename');
}

function renderMaps() {
    const content = document.getElementById('content');

    document.getElementById('topbar-actions').innerHTML = `
        <button class="btn btn-sm" id="btn-import">Import</button>
        <button class="btn btn-sm btn-primary" id="btn-new-map">Build a map</button>`;

    content.innerHTML = '<div class="empty">Loading maps…</div>';

    loadMaps().then(() => {
        content.innerHTML = APP.maps.length === 0
            ? `<div class="empty"><strong>No maps yet</strong>Build one in the world — place your boundary, spawns and cover, then save it.</div>`
            : `<div class="card pad-0"><div class="list">
                ${APP.maps.map(map => `
                    <div class="list-row">
                        <div class="list-main">
                            <div class="list-name">
                                ${esc(map.name)}
                                ${map.enabled ? '<span class="tag green">live</span>' : '<span class="tag muted">off</span>'}
                                ${map.preset ? '<span class="tag accent">preset</span>' : ''}
                            </div>
                            <div class="list-sub">
                                ${map.spawns} spawns &middot; ${map.props} props &middot; ${map.points} capture points &middot; ${esc(map.boundary)} boundary
                                ${map.author ? ` &middot; by ${esc(map.author)}` : ''}
                            </div>
                            <div class="row wrap" style="gap:5px;margin-top:7px">${modeChips(map.modes)}</div>
                        </div>
                        <div class="list-actions">
                            <button class="btn btn-sm" data-edit="${map.id}">Edit</button>
                            <button class="btn btn-sm" data-toggle-map="${map.id}">${map.enabled ? 'Disable' : 'Enable'}</button>
                            <button class="btn btn-sm" data-rename="${map.id}">Rename</button>
                            <button class="btn btn-sm" data-copy="${map.id}">Duplicate</button>
                            <button class="btn btn-sm" data-export="${map.id}">Export</button>
                            <button class="btn btn-sm btn-danger" data-delete="${map.id}">Delete</button>
                        </div>
                    </div>`).join('')}
            </div></div>`;

        content.querySelectorAll('[data-edit]').forEach(el => {
            el.addEventListener('click', () => openEditor(Number(el.dataset.edit)));
        });

        content.querySelectorAll('[data-toggle-map]').forEach(el => {
            el.addEventListener('click', async () => {
                const map = APP.maps.find(m => String(m.id) === el.dataset.toggleMap);
                const result = await nui('toggleMap', { id: map.id, enabled: !map.enabled });
                if (!reportResult(result, map.enabled ? 'Map disabled' : 'Map live')) return;

                APP.maps = result.maps || APP.maps;
                renderMaps();
            });
        });

        content.querySelectorAll('[data-rename]').forEach(el => {
            el.addEventListener('click', () => {
                const map = APP.maps.find(m => String(m.id) === el.dataset.rename);
                if (map) renameMapModal(map);
            });
        });

        content.querySelectorAll('[data-copy]').forEach(el => {
            el.addEventListener('click', async () => {
                const result = await nui('duplicateMap', { id: Number(el.dataset.copy) });
                if (!reportResult(result, 'Copied')) return;

                APP.maps = result.maps || APP.maps;
                renderMaps();
            });
        });

        content.querySelectorAll('[data-export]').forEach(el => {
            el.addEventListener('click', () => {
                const map = APP.maps.find(m => String(m.id) === el.dataset.export);
                if (map) exportMapModal(map);
            });
        });

        content.querySelectorAll('[data-delete]').forEach(el => {
            el.addEventListener('click', () => {
                const map = APP.maps.find(m => String(m.id) === el.dataset.delete);
                if (!map) return;

                confirmDanger('Delete this map', `${map.name} goes for good. Any lobby sitting on it moves to another map.`, async () => {
                    const result = await nui('deleteMap', { id: map.id });
                    if (!reportResult(result, 'Deleted')) return;

                    APP.maps = result.maps || APP.maps;
                    renderMaps();
                });
            });
        });
    });

    document.getElementById('btn-new-map').addEventListener('click', () => openEditor(null));
    document.getElementById('btn-import').addEventListener('click', importMapModal);
}
