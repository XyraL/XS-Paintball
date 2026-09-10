const EDITOR = { section: 'layout', propCategory: 'all', propSearch: '', propModel: null };

function editorMap() {
    if (!APP.editor) APP.editor = { map: null, check: null };
    if (!APP.editor.map) {
        APP.editor.map = {
            name: 'New Map', description: '', author: '', weather: 'EXTRASUNNY', time: 12,
            bounds: { kind: 'circle', center: null, radius: 80, points: [], minZ: -20, maxZ: 60 },
            lobby: null,
            spawns: { red: [], blue: [], green: [], yellow: [], ffa: [] },
            flags: {}, capturePoints: [], props: [], spectate: [],
        };
    }
    return APP.editor.map;
}

async function editorSync(rerender = true) {
    const result = await nui('builderSync', { map: editorMap() });
    if (result && result.map) APP.editor.map = result.map;

    const check = await nui('validateMap', { map: editorMap() });
    if (check && check.ok) APP.editor.check = check.check;

    if (rerender) renderEditor();
}

async function editorPlace(kind, payload = {}) {
    const result = await nui('builderPlace', { kind, ...payload });

    if (result && result.map) APP.editor.map = result.map;

    if (result && !result.ok && result.error) {
        toast('Not placed', result.error, 'error');
    }

    await editorSync();
}

async function editorRemove(kind, payload = {}) {
    const result = await nui('builderRemove', { kind, ...payload });
    if (result && result.map) APP.editor.map = result.map;
    await editorSync();
}

function teamsList() {
    return APP.boot.teamOrder || ['red', 'blue', 'green', 'yellow'];
}

function editorSection(id, label) {
    return `<button class="slot-tab ${EDITOR.section === id ? 'active' : ''}" data-section="${id}">${esc(label)}</button>`;
}

function layoutPanel(map) {
    const teams = teamsList();

    return `
        <div class="section-title">Arena boundary</div>
        <div class="card">
            <div class="row" style="gap:10px;align-items:center;margin-bottom:12px">
                <span class="tag ${map.bounds.kind === 'circle' ? 'accent' : 'muted'}">${esc(map.bounds.kind)}</span>
                ${map.bounds.kind === 'circle'
                    ? `<span class="tag mono">${map.bounds.center ? `${map.bounds.radius}m radius` : 'no centre yet'}</span>`
                    : `<span class="tag mono">${map.bounds.points.length} corners</span>`}
                <div class="spacer"></div>
                <button class="btn btn-sm" data-place="centre">Circle: place centre</button>
                <button class="btn btn-sm" data-place="boundary" data-multi="1">Polygon: walk the corners</button>
                ${map.bounds.points.length ? '<button class="btn btn-sm btn-danger" data-clear-boundary>Clear corners</button>' : ''}
            </div>
            <div class="row">
                <div class="grow">${field('Floor height', textInput('bounds-minz', map.bounds.minZ, '', 'number'))}</div>
                <div class="grow">${field('Ceiling height', textInput('bounds-maxz', map.bounds.maxZ, '', 'number'))}</div>
            </div>
            <div class="field-hint">Anyone who leaves the boundary gets a countdown and then goes out. A circle is quickest, a polygon fits an MLO better.</div>
        </div>

        <div class="section-title">Spawns</div>
        <div class="grid two">
            ${teams.concat(['ffa']).map(team => {
                const list = map.spawns[team] || [];
                const label = team === 'ffa' ? 'Free for all' : ((APP.boot.teams[team] || {}).label || team);

                return `
                    <div class="card">
                        <div class="card-head">
                            <div class="card-title">${esc(label)}</div>
                            <div class="spacer"></div>
                            <span class="tag ${list.length ? 'accent' : 'muted'}">${list.length}</span>
                        </div>
                        <div class="row" style="gap:6px;margin-bottom:10px">
                            <button class="btn btn-sm btn-block" data-place="spawn" data-team="${team}">Add spawn</button>
                        </div>
                        ${list.length === 0 ? '<div class="field-hint" style="margin:0">Nothing placed.</div>' : `
                            <div class="list-scroll list">
                                ${list.map((point, index) => `
                                    <div class="list-row" style="padding:7px 0">
                                        <div class="list-main">
                                            <div class="list-sub mono">${point.x.toFixed(1)}, ${point.y.toFixed(1)}, ${point.z.toFixed(1)}</div>
                                        </div>
                                        <button class="btn btn-sm btn-ghost" data-go="${team}:${index}">Go</button>
                                        <button class="btn btn-sm btn-danger" data-del-spawn="${team}:${index}">&times;</button>
                                    </div>`).join('')}
                            </div>`}
                    </div>`;
            }).join('')}
        </div>

        <div class="section-title">Staging and cameras</div>
        <div class="grid two">
            <div class="card">
                <div class="card-head"><div class="card-title">Fallback point</div></div>
                <div class="field-hint" style="margin:0 0 10px">Where anyone lands if they spawn into a mode with no spawns placed. Optional.</div>
                <div class="row" style="gap:6px">
                    <button class="btn btn-sm grow" data-place="lobby">${map.lobby ? 'Move it' : 'Place it'}</button>
                    ${map.lobby ? '<button class="btn btn-sm btn-danger" data-del-lobby>Clear</button>' : ''}
                </div>
            </div>
            <div class="card">
                <div class="card-head">
                    <div class="card-title">Spectator cameras</div>
                    <div class="spacer"></div>
                    <span class="tag ${map.spectate.length ? 'accent' : 'muted'}">${map.spectate.length}</span>
                </div>
                <div class="field-hint" style="margin:0 0 10px">The first one is where a spectator's camera starts. Optional.</div>
                <button class="btn btn-sm btn-block" data-place="spectate">Add camera</button>
                ${map.spectate.map((point, index) => `
                    <div class="list-row" style="padding:7px 0">
                        <div class="list-main"><div class="list-sub mono">Camera ${index + 1}</div></div>
                        <button class="btn btn-sm btn-danger" data-del-spectate="${index}">&times;</button>
                    </div>`).join('')}
            </div>
        </div>`;
}

function objectivesPanel(map) {
    const teams = teamsList().slice(0, 2);

    return `
        <div class="section-title">Capture the flag</div>
        <div class="grid two">
            ${teams.map(team => {
                const flag = map.flags[team];
                return `
                    <div class="card">
                        <div class="card-head">
                            <div class="card-title">${esc((APP.boot.teams[team] || {}).label || team)} flag</div>
                            <div class="spacer"></div>
                            <span class="tag ${flag ? 'green' : 'muted'}">${flag ? 'placed' : 'missing'}</span>
                        </div>
                        <div class="row" style="gap:6px">
                            <button class="btn btn-sm grow" data-place="flag" data-team="${team}">${flag ? 'Move it' : 'Place it'}</button>
                            ${flag ? `<button class="btn btn-sm btn-danger" data-del-flag="${team}">Clear</button>` : ''}
                        </div>
                    </div>`;
            }).join('')}
        </div>

        <div class="section-title">Domination points</div>
        <div class="card">
            <div class="card-head">
                <div class="card-title">Capture points</div>
                <div class="spacer"></div>
                <span class="tag ${map.capturePoints.length ? 'accent' : 'muted'}">${map.capturePoints.length} / ${APP.boot.builder.limits.capturePoints}</span>
            </div>
            <button class="btn btn-sm btn-block" data-place="capture" style="margin-bottom:10px">Add a capture point</button>
            ${map.capturePoints.length === 0
                ? '<div class="field-hint" style="margin:0">Domination needs at least one. Two or three plays best.</div>'
                : `<div class="list">
                    ${map.capturePoints.map((point, index) => `
                        <div class="list-row" style="padding:8px 0">
                            <div class="list-main">
                                <div class="list-name" style="font-size:12.5px">Point ${esc(point.id)}</div>
                                <div class="list-sub mono">${point.radius}m &middot; ${point.x.toFixed(1)}, ${point.y.toFixed(1)}</div>
                            </div>
                            <button class="btn btn-sm btn-ghost" data-go-point="${index}">Go</button>
                            <button class="btn btn-sm btn-danger" data-del-point="${index}">&times;</button>
                        </div>`).join('')}
                </div>`}
        </div>`;
}

function propsPanel(map) {
    const builder = APP.boot.builder;
    const categories = [{ id: 'all', label: 'Everything' }].concat(builder.categories || []);

    const props = (builder.props || []).filter(prop => {
        if (EDITOR.propCategory !== 'all' && prop.category !== EDITOR.propCategory) return false;
        if (!EDITOR.propSearch) return true;

        const needle = EDITOR.propSearch.toLowerCase();
        return prop.label.toLowerCase().includes(needle) || prop.model.toLowerCase().includes(needle);
    });

    const custom = EDITOR.propSearch && !props.some(p => p.model === EDITOR.propSearch);

    return `
        <div class="row" style="gap:16px;align-items:flex-start">
            <div class="grow">
                <div class="row" style="gap:8px;margin-bottom:12px">
                    <input type="text" id="prop-search" value="${esc(EDITOR.propSearch)}" placeholder="Search props, or type any model name">
                </div>

                <div class="slot-tabs">
                    ${categories.map(cat => `
                        <button class="slot-tab ${EDITOR.propCategory === cat.id ? 'active' : ''}" data-prop-cat="${cat.id}">${esc(cat.label)}</button>`).join('')}
                </div>

                ${custom ? `
                    <div class="card highlight" style="margin-bottom:12px">
                        <div class="row" style="align-items:center">
                            <div class="grow">
                                <div class="list-name" style="font-size:12.5px">Use "${esc(EDITOR.propSearch)}" as a model name</div>
                                <div class="list-sub">Anything your server streams works, even if it is not in the list.</div>
                            </div>
                            <button class="btn btn-sm btn-primary" data-pick-prop="${esc(EDITOR.propSearch)}">Pick it</button>
                        </div>
                    </div>` : ''}

                <div class="grid auto">
                    ${props.map(prop => `
                        <div class="prop-item ${EDITOR.propModel === prop.model ? 'selected' : ''}" data-pick-prop="${esc(prop.model)}">
                            <div class="grow">
                                <div>${esc(prop.label)}</div>
                                <div class="prop-model">${esc(prop.model)}</div>
                            </div>
                        </div>`).join('')}
                </div>
                ${props.length === 0 && !custom ? '<div class="empty">Nothing matches that.</div>' : ''}
            </div>

            <div class="col" style="width:300px;flex:0 0 300px">
                <div class="card">
                    <div class="card-head">
                        <div class="card-title">Placed</div>
                        <div class="spacer"></div>
                        <span class="tag ${map.props.length ? 'accent' : 'muted'}">${map.props.length} / ${APP.boot.builder.limits.props}</span>
                    </div>

                    <div class="field-hint" style="margin:0 0 10px">
                        Selected: <strong>${esc(EDITOR.propModel || 'nothing yet')}</strong>
                    </div>

                    <button class="btn btn-sm btn-primary btn-block" data-place="prop" data-multi="1" ${EDITOR.propModel ? '' : 'disabled'}>
                        Place, keep placing
                    </button>
                    <button class="btn btn-sm btn-block" data-place="prop" style="margin-top:6px" ${EDITOR.propModel ? '' : 'disabled'}>
                        Place one
                    </button>
                    <button class="btn btn-sm btn-block" id="btn-redraw-props" style="margin-top:6px">
                        Redraw them in the world
                    </button>

                    ${map.props.length ? `
                        <div class="list-scroll list" style="margin-top:12px">
                            ${map.props.map((prop, index) => `
                                <div class="list-row" style="padding:7px 0">
                                    <div class="list-main">
                                        <div class="list-sub">${esc(prop.model)}</div>
                                    </div>
                                    <button class="btn btn-sm btn-danger" data-del-prop="${index}">&times;</button>
                                </div>`).join('')}
                        </div>` : ''}
                </div>
            </div>
        </div>`;
}

function detailsPanel(map) {
    const weathers = APP.boot.builder.weathers || [];
    const hours = [];
    for (let h = 0; h < 24; h += 1) hours.push({ value: h, label: `${String(h).padStart(2, '0')}:00` });

    return `
        <div class="card">
            ${field('Map name', textInput('map-name', map.name))}
            ${field('Description', textInput('map-desc', map.description, 'A line for the lobby list'))}
            <div class="row">
                <div class="grow">${field('Weather', selectInput('map-weather', weathers, map.weather))}</div>
                <div class="grow">${field('Time of day', selectInput('map-time', hours, map.time))}</div>
            </div>
            <div class="field-hint">Weather and time are forced for everyone inside the match and put back when it ends.</div>
        </div>`;
}

function checkPanel() {
    const check = APP.editor.check;
    if (!check) return '';

    const modes = (APP.boot.modes || []).map(mode => {
        const on = check.modes && check.modes[mode.id];
        return `<span class="mode-chip ${on ? 'on' : ''}">${esc(mode.label)}</span>`;
    }).join('');

    return `
        <div class="card">
            <div class="card-head"><div class="card-title">Ready to run</div></div>
            <div class="row wrap" style="gap:5px;margin-bottom:12px">${modes}</div>

            ${(check.errors || []).map(e => `<div class="check-line err"><span class="dot"></span><span>${esc(e)}</span></div>`).join('')}
            ${(check.warnings || []).map(w => `<div class="check-line warn"><span class="dot"></span><span>${esc(w)}</span></div>`).join('')}
            ${check.ok && (check.warnings || []).length === 0
                ? '<div class="check-line ok"><span class="dot"></span><span>Nothing to fix.</span></div>' : ''}
        </div>`;
}

function renderEditor() {
    const content = document.getElementById('content');
    const map = editorMap();

    document.getElementById('page-sub').textContent = `${map.name} — everything is placed in the world`;

    document.getElementById('topbar-actions').innerHTML = `
        <button class="btn btn-sm" id="btn-editor-look">Look around</button>
        <button class="btn btn-sm" id="btn-editor-go">Go to arena</button>
        <button class="btn btn-sm" id="btn-editor-back">Close</button>
        <button class="btn btn-sm btn-primary" id="btn-editor-save">Save map</button>`;

    const panel = EDITOR.section === 'objectives' ? objectivesPanel(map)
        : EDITOR.section === 'props' ? propsPanel(map)
        : EDITOR.section === 'details' ? detailsPanel(map)
        : layoutPanel(map);

    content.innerHTML = `
        <div class="slot-tabs">
            ${editorSection('layout', 'Layout')}
            ${editorSection('objectives', 'Objectives')}
            ${editorSection('props', 'Props')}
            ${editorSection('details', 'Details')}
        </div>

        <div class="editor-grid">
            <div class="editor-tools">
                ${checkPanel()}

                <div class="card">
                    <div class="card-head"><div class="card-title">How it works</div></div>
                    <div class="field-hint" style="margin:0">
                        Every button here drops you into a free camera. WASD flies, the mouse aims, ENTER places and BACKSPACE cancels.
                        SPACE pins a point where it is, X drops it to the floor, Z cycles grid snapping.
                    </div>
                </div>

                <div class="card">
                    <div class="card-head"><div class="card-title">Totals</div></div>
                    <div class="list">
                        <div class="list-row" style="padding:6px 0"><div class="list-main"><div class="list-sub">Spawns</div></div><span class="tag mono">${teamsList().concat(['ffa']).reduce((sum, t) => sum + (map.spawns[t] || []).length, 0)}</span></div>
                        <div class="list-row" style="padding:6px 0"><div class="list-main"><div class="list-sub">Props</div></div><span class="tag mono">${map.props.length}</span></div>
                        <div class="list-row" style="padding:6px 0"><div class="list-main"><div class="list-sub">Capture points</div></div><span class="tag mono">${map.capturePoints.length}</span></div>
                        <div class="list-row" style="padding:6px 0"><div class="list-main"><div class="list-sub">Flags</div></div><span class="tag mono">${Object.keys(map.flags).length}</span></div>
                    </div>
                </div>
            </div>

            <div>${panel}</div>
        </div>`;

    content.querySelectorAll('[data-section]').forEach(el => {
        el.addEventListener('click', () => {
            EDITOR.section = el.dataset.section;
            renderEditor();
        });
    });

    content.querySelectorAll('[data-place]').forEach(el => {
        el.addEventListener('click', () => {
            editorPlace(el.dataset.place, {
                team: el.dataset.team,
                model: EDITOR.propModel,
                multi: el.dataset.multi === '1',
            });
        });
    });

    content.querySelectorAll('[data-pick-prop]').forEach(el => {
        el.addEventListener('click', () => {
            EDITOR.propModel = el.dataset.pickProp;
            renderEditor();
        });
    });

    const search = document.getElementById('prop-search');
    if (search) {
        search.addEventListener('input', () => {
            EDITOR.propSearch = search.value.trim();
            renderEditor();
            const again = document.getElementById('prop-search');
            again.focus();
            again.setSelectionRange(again.value.length, again.value.length);
        });
    }

    const redraw = document.getElementById('btn-redraw-props');
    if (redraw) {
        redraw.addEventListener('click', async () => {
            const result = await nui('builderPreview');
            reportResult(result, 'Redrawn', 'Every prop on this map is back in the world.');
        });
    }

    content.querySelectorAll('[data-prop-cat]').forEach(el => {
        el.addEventListener('click', () => {
            EDITOR.propCategory = el.dataset.propCat;
            renderEditor();
        });
    });

    content.querySelectorAll('[data-del-spawn]').forEach(el => {
        el.addEventListener('click', () => {
            const [team, index] = el.dataset.delSpawn.split(':');
            editorRemove('spawn', { team, index: Number(index) + 1 });
        });
    });

    content.querySelectorAll('[data-go]').forEach(el => {
        el.addEventListener('click', () => {
            const [team, index] = el.dataset.go.split(':');
            const point = (map.spawns[team] || [])[Number(index)];
            if (point) nui('builderTeleport', { point });
        });
    });

    content.querySelectorAll('[data-go-point]').forEach(el => {
        el.addEventListener('click', () => {
            const point = map.capturePoints[Number(el.dataset.goPoint)];
            if (point) nui('builderTeleport', { point });
        });
    });

    content.querySelectorAll('[data-del-prop]').forEach(el => {
        el.addEventListener('click', () => editorRemove('prop', { index: Number(el.dataset.delProp) + 1 }));
    });

    content.querySelectorAll('[data-del-point]').forEach(el => {
        el.addEventListener('click', () => editorRemove('capture', { index: Number(el.dataset.delPoint) + 1 }));
    });

    content.querySelectorAll('[data-del-flag]').forEach(el => {
        el.addEventListener('click', () => editorRemove('flag', { team: el.dataset.delFlag }));
    });

    content.querySelectorAll('[data-del-spectate]').forEach(el => {
        el.addEventListener('click', () => editorRemove('spectate', { index: Number(el.dataset.delSpectate) + 1 }));
    });

    const delLobby = content.querySelector('[data-del-lobby]');
    if (delLobby) delLobby.addEventListener('click', () => editorRemove('lobby'));

    const clearBoundary = content.querySelector('[data-clear-boundary]');
    if (clearBoundary) {
        clearBoundary.addEventListener('click', () => {
            map.bounds.points = [];
            map.bounds.kind = 'circle';
            editorSync();
        });
    }

    ['bounds-minz', 'bounds-maxz'].forEach(id => {
        const el = document.getElementById(id);
        if (!el) return;

        el.addEventListener('change', () => {
            map.bounds.minZ = numberValue('bounds-minz', map.bounds.minZ);
            map.bounds.maxZ = numberValue('bounds-maxz', map.bounds.maxZ);
            editorSync(false);
        });
    });

    ['map-name', 'map-desc', 'map-weather', 'map-time'].forEach(id => {
        const el = document.getElementById(id);
        if (!el) return;

        el.addEventListener('change', () => {
            map.name = value('map-name', map.name);
            map.description = value('map-desc', map.description);
            map.weather = value('map-weather', map.weather);
            map.time = numberValue('map-time', map.time);
            editorSync(false);
            document.getElementById('page-sub').textContent = `${map.name} — everything is placed in the world`;
        });
    });

    document.getElementById('btn-editor-look').addEventListener('click', () => nui('builderLook'));
    document.getElementById('btn-editor-go').addEventListener('click', () => nui('builderTeleport', {}));

    document.getElementById('btn-editor-back').addEventListener('click', () => {
        nui('builderClose');
        APP.editor = null;
        setTab('maps', true);
    });

    document.getElementById('btn-editor-save').addEventListener('click', async () => {
        const result = await nui('saveMap', { map: editorMap() });
        if (!reportResult(result, 'Map saved', 'It is live for every lobby now.')) return;

        APP.editor.map = result.map;
        APP.editor.check = result.check;
        renderEditor();
    });
}
