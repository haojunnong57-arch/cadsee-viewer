/* CadSee 离线 Web 查看器
 * 统一处理：STL/OBJ/PLY/glTF/3MF（three.js）、STEP/IGES/BREP（occt-import-js）、DXF（three-dxf）
 * 与 Swift 侧通过 window.webkit.messageHandlers.cadsee 通信。
 */
(function () {
  'use strict';

  var META = window.CADSEE_META || { ext: 'stl', mode: '3d' };
  var EXT = String(META.ext || 'stl').toLowerCase();
  var IS_DXF = META.mode === 'dxf';
  var IS_CAD = (EXT === 'step' || EXT === 'stp' || EXT === 'iges' || EXT === 'igs' || EXT === 'brep');
  var DEFAULT_COLOR = 0xb0bac4;

  function post(payload) {
    try {
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.cadsee) {
        window.webkit.messageHandlers.cadsee.postMessage(payload);
      } else if (window.console) {
        console.log('[CADSEE]', JSON.stringify(payload));
      }
    } catch (e) { /* ignore */ }
  }

  function statusEl() { return document.getElementById('status'); }
  function statusTextEl() { return document.getElementById('statusText'); }

  function setStatus(text) {
    var el = statusTextEl();
    if (el) { el.textContent = text; }
  }

  function hideStatus() {
    var el = statusEl();
    if (el) { el.classList.add('hidden'); }
  }

  function fail(message) {
    setStatus('无法打开：' + message);
    post({ type: 'status', value: 'failed', message: String(message) });
  }

  // ---------- 状态 ----------
  var state = {
    renderer: null,
    scene: null,
    camera: null,
    controls: null,
    grid: null,
    root: null,
    meshes: [],
    themeDark: true,
    displayMode: 'solid',
    target: new THREE.Vector3(),
    radius: 1,
    boxMinY: 0
  };

  // ---------- 文件读取 ----------
  function fetchModelBytes() {
    return fetch('model.' + EXT).then(function (resp) {
      if (!resp.ok) { throw new Error('读取文件失败 (' + resp.status + ')'); }
      return resp.arrayBuffer();
    });
  }

  function fetchModelText() {
    return fetchModelBytes().then(function (buffer) {
      var text = new TextDecoder('utf-8').decode(buffer);
      if (text.charCodeAt(0) === 0xFEFF) { text = text.slice(1); } // 去掉 BOM
      return text;
    });
  }

  // ---------- 场景 ----------
  function buildScene() {
    var container = document.getElementById('viewer');
    var renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 3));
    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.outputEncoding = THREE.sRGBEncoding;
    container.appendChild(renderer.domElement);

    var scene = new THREE.Scene();
    var camera = new THREE.PerspectiveCamera(
      50, window.innerWidth / window.innerHeight, 0.01, 200000
    );
    camera.position.set(2, -2, 3);

    var hemi = new THREE.HemisphereLight(0xffffff, 0x444a52, 0.85);
    var dir = new THREE.DirectionalLight(0xffffff, 1.05);
    dir.position.set(2, 4, 3);
    scene.add(hemi);
    scene.add(dir);

    var controls = new THREE.OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;
    controls.dampingFactor = 0.08;
    controls.target.set(0, 0, 0);

    state.renderer = renderer;
    state.scene = scene;
    state.camera = camera;
    state.controls = controls;

    applyTheme(state.themeDark);
    window.addEventListener('resize', onResize);
    animate();
  }

  function animate() {
    requestAnimationFrame(animate);
    if (state.renderer && state.scene && state.camera) {
      if (state.controls) { state.controls.update(); }
      state.renderer.render(state.scene, state.camera);
    }
  }

  function onResize() {
    if (!state.renderer || !state.camera) { return; }
    state.camera.aspect = window.innerWidth / window.innerHeight;
    state.camera.updateProjectionMatrix();
    state.renderer.setSize(window.innerWidth, window.innerHeight);
  }

  function applyTheme(dark) {
    state.themeDark = !!dark;
    var hex = state.themeDark ? 0x141518 : 0xf2f3f5;
    document.body.style.background = state.themeDark ? '#141518' : '#f2f3f5';
    if (state.scene) { state.scene.background = new THREE.Color(hex); }
    if (state.grid && state.grid.material) {
      state.grid.material.opacity = state.themeDark ? 0.30 : 0.22;
      state.grid.material.needsUpdate = true;
    }
  }

  // ---------- 网格 ----------
  function updateGrid(box) {
    if (state.grid) {
      state.scene.remove(state.grid);
      state.grid.geometry.dispose();
      state.grid.material.dispose();
      state.grid = null;
    }
    var span = Math.max(state.radius * 2, 0.01);
    var gridSize = span * 2.4;
    var colorCenter = state.themeDark ? 0x3a3f47 : 0xb9c0c9;
    var colorEdge = state.themeDark ? 0x24272c : 0xd9dde3;
    var grid = new THREE.GridHelper(gridSize, 24, colorCenter, colorEdge);
    grid.material.transparent = true;
    grid.material.opacity = state.themeDark ? 0.30 : 0.22;
    grid.material.depthWrite = false;
    grid.position.y = box.min.y - span * 0.001;
    state.grid = grid;
    state.scene.add(grid);
  }

  // ---------- 取景 ----------
  function fitView() {
    if (!state.root || !state.camera) { return; }
    var box = new THREE.Box3().setFromObject(state.root);
    if (box.isEmpty()) {
      box.set(new THREE.Vector3(-1, -1, -1), new THREE.Vector3(1, 1, 1));
    }
    var size = box.getSize(new THREE.Vector3());
    var center = box.getCenter(new THREE.Vector3());
    var radius = Math.max(size.x, size.y, size.z) / 2;
    if (!(radius > 0)) { radius = 1; }
    state.radius = radius;
    state.boxMinY = box.min.y;
    state.target.copy(center);
    placeCamera(center, radius, new THREE.Vector3(0.55, -0.62, 0.9));
    state.controls.target.copy(center);
    state.controls.update();
    updateGrid(box);
  }

  function placeCamera(center, radius, rawDir) {
    var dir = rawDir.clone().normalize();
    var dist = radius / Math.tan(THREE.MathUtils.degToRad(25)) * 1.6;
    state.camera.position.copy(center).addScaledVector(dir, dist);
    state.camera.near = Math.max(dist / 1000, radius / 10000);
    state.camera.far = Math.max(dist * 100, radius * 200);
    state.camera.updateProjectionMatrix();
  }

  function setViewAngle(name) {
    if (!state.root || !state.camera) { return; }
    var dirs = {
      iso: new THREE.Vector3(0.55, -0.62, 0.9),
      front: new THREE.Vector3(0, 0, 1),
      top: new THREE.Vector3(0.01, 1, 0.01)
    };
    var dir = dirs[name] || dirs.iso;
    placeCamera(state.target, state.radius, dir);
    state.controls.target.copy(state.target);
    state.controls.update();
  }

  function setDisplayMode(mode) {
    state.displayMode = mode === 'wire' ? 'wire' : 'solid';
    state.meshes.forEach(function (mesh) {
      if (mesh.material) { mesh.material.wireframe = state.displayMode === 'wire'; }
    });
  }

  // ---------- 模型装配 ----------
  function makeMaterial(color, vertexColors) {
    return new THREE.MeshStandardMaterial({
      color: color,
      metalness: 0.12,
      roughness: 0.55,
      side: THREE.DoubleSide,
      vertexColors: !!vertexColors
    });
  }

  function addObject(obj) {
    var meshes = [];
    obj.traverse(function (child) {
      if (!child.isMesh) { return; }
      var material = child.material;
      if (!material) { return; }
      if (material.isMeshStandardMaterial || material.isMeshPhongMaterial ||
          material.isMeshLambertMaterial || material.isMeshBasicMaterial) {
        material.side = THREE.DoubleSide;
      } else {
        var color = (material.color && material.color.getHex) ? material.color.getHex() : DEFAULT_COLOR;
        var map = material.map || null;
        var replacement = makeMaterial(color, !!material.vertexColors);
        if (map) { replacement.map = map; }
        child.material = replacement;
      }
      meshes.push(child);
    });
    if (state.root) { state.scene.remove(state.root); }
    state.root = obj;
    state.meshes = meshes;
    state.scene.add(obj);
    fitView();
    var triangles = countTriangles(obj);
    if (triangles > 0) {
      post({ type: 'stats', triangles: triangles });
    }
  }

  function countTriangles(obj) {
    var total = 0;
    obj.traverse(function (child) {
      if (!child.isMesh || !child.geometry) { return; }
      var geo = child.geometry;
      var count = 0;
      if (geo.index) {
        count = geo.index.count / 3;
      } else if (geo.attributes && geo.attributes.position) {
        count = geo.attributes.position.count / 3;
      }
      total += Math.floor(count);
    });
    return total;
  }

  function ensureNormals(geometry) {
    if (!geometry.attributes.normal) {
      geometry.computeVertexNormals();
    }
  }

  function finish() {
    hideStatus();
    post({ type: 'status', value: 'ready' });
  }

  // ---------- 各格式加载 ----------
  function loadThreeMesh() {
    if (EXT === 'stl') {
      setStatus('正在解析 STL…');
      fetchModelBytes().then(function (buffer) {
        var geometry = new THREE.STLLoader().parse(buffer);
        ensureNormals(geometry);
        var useColors = !!geometry.attributes.color;
        addObject(new THREE.Mesh(geometry, makeMaterial(DEFAULT_COLOR, useColors)));
        finish();
      }).catch(fail);
      return;
    }
    if (EXT === 'obj') {
      setStatus('正在解析 OBJ…');
      fetchModelText().then(function (text) {
        var group = new THREE.OBJLoader().parse(text);
        addObject(group);
        finish();
      }).catch(fail);
      return;
    }
    if (EXT === 'ply') {
      setStatus('正在解析 PLY…');
      fetchModelBytes().then(function (buffer) {
        var geometry = new THREE.PLYLoader().parse(buffer);
        ensureNormals(geometry);
        var useColors = !!geometry.attributes.color;
        addObject(new THREE.Mesh(geometry, makeMaterial(DEFAULT_COLOR, useColors)));
        finish();
      }).catch(fail);
      return;
    }
    if (EXT === 'gltf' || EXT === 'glb') {
      setStatus('正在解析 glTF…');
      fetchModelBytes().then(function (buffer) {
        new THREE.GLTFLoader().parse(buffer, '', function (gltf) {
          addObject(gltf.scene || gltf);
          finish();
        }, function (err) {
          fail(err && err.message ? err.message : 'glTF 解析失败');
        });
      }).catch(fail);
      return;
    }
    if (EXT === '3mf') {
      setStatus('正在解析 3MF…');
      fetchModelBytes().then(function (buffer) {
        var loader = new THREE.ThreeMFLoader();
        var group = loader.parse(buffer);
        addObject(group);
        finish();
      }).catch(fail);
      return;
    }
    fail('暂不支持 .' + EXT + ' 格式');
  }

  function loadOcct() {
    setStatus('正在初始化 CAD 引擎…');
    fetchModelBytes().then(function (buffer) {
      var bytes = new Uint8Array(buffer);
      var factory = window.occtimportjs;
      if (typeof factory !== 'function') {
        fail('CAD 引擎加载失败');
        return;
      }
      factory({
        locateFile: function (name) { return 'js/occt/' + name; }
      }).then(function (occt) {
        setStatus('正在解析 ' + EXT.toUpperCase() + ' 几何…');
        var readFile = null;
        if (EXT === 'step' || EXT === 'stp') { readFile = occt.ReadStepFile; }
        else if (EXT === 'iges' || EXT === 'igs') { readFile = occt.ReadIgesFile; }
        else if (EXT === 'brep') { readFile = occt.ReadBrepFile; }
        if (typeof readFile !== 'function') {
          fail('CAD 引擎缺少解析接口');
          return;
        }
        var result = readFile.call(occt, bytes, null);
        if (!result || !result.success) {
          fail('CAD 解析失败');
          return;
        }
        var meshes = result.meshes || [];
        if (!meshes.length) {
          fail('文件中没有可显示的几何体');
          return;
        }
        var root = new THREE.Group();
        meshes.forEach(function (mesh) {
          var attributes = mesh.attributes || {};
          var position = attributes.position && attributes.position.array;
          if (!position) { return; }
          var geometry = new THREE.BufferGeometry();
          geometry.setAttribute('position', new THREE.BufferAttribute(position, 3));
          if (attributes.normal && attributes.normal.array) {
            geometry.setAttribute('normal', new THREE.BufferAttribute(attributes.normal.array, 3));
          }
          if (mesh.index && mesh.index.array) {
            geometry.setIndex(new THREE.BufferAttribute(mesh.index.array, 1));
          }
          var color = DEFAULT_COLOR;
          if (mesh.color && mesh.color.length >= 3) {
            color = new THREE.Color(mesh.color[0], mesh.color[1], mesh.color[2]);
          }
          root.add(new THREE.Mesh(geometry, makeMaterial(color)));
        });
        addObject(root);
        finish();
      }).catch(function (err) {
        fail('CAD 引擎初始化失败：' + (err && err.message ? err.message : err));
      });
    }).catch(fail);
  }

  function loadDxf() {
    setStatus('正在渲染图纸…');
    fetchModelText().then(function (text) {
      var container = document.getElementById('viewer');
      var dxf = window.ThreeDxf;
      var Parser = window.DxfParser;
      if (!dxf || typeof dxf.Viewer !== 'function') {
        fail('DXF 渲染库加载失败');
        return;
      }
      if (typeof Parser !== 'function') {
        fail('DXF 解析库加载失败');
        return;
      }
      var parsed;
      try {
        parsed = new Parser().parseSync(text);
      } catch (err) {
        fail('DXF 解析失败：' + (err && err.message ? err.message : err));
        return;
      }
      var viewer = new dxf.Viewer(parsed, container, window.innerWidth, window.innerHeight, THREE);
      state.dxfViewer = viewer;
      window.addEventListener('resize', function () {
        try {
          if (state.dxfViewer && typeof state.dxfViewer.resize === 'function') {
            state.dxfViewer.resize(window.innerWidth, window.innerHeight);
          }
        } catch (e) { /* ignore */ }
      });
      document.body.style.background = '#ffffff';
      hideStatus();
      post({ type: 'status', value: 'ready' });
    }).catch(fail);
  }

  // ---------- 对外接口（Swift 调用） ----------
  window.CADSEE = {
    setDisplayMode: function (mode) {
      if (IS_DXF) { return; }
      setDisplayMode(mode);
    },
    setTheme: function (dark) {
      applyTheme(dark);
    },
    setViewAngle: function (name) {
      if (IS_DXF) { return; }
      setViewAngle(name);
    },
    resetView: function () {
      if (IS_DXF) {
        // three-dxf 构造时已自动取景；无独立缩放接口时保持现状
        return;
      }
      fitView();
    }
  };

  // ---------- 启动 ----------
  if (IS_DXF) {
    loadDxf();
  } else {
    buildScene();
    if (IS_CAD) {
      loadOcct();
    } else {
      loadThreeMesh();
    }
  }
})();
