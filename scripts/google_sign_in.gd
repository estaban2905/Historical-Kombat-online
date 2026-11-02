## Puente con Google Identity Services (solo en la versión web del juego).
## El botón oficial de Google es un elemento HTML: se coloca encima del canvas, justo
## donde la pantalla de Login deja un hueco. Al elegir cuenta, Google entrega un ID token
## que el juego manda a POST /auth/google (Backend.sign_in_google).
## El Client ID llega en window.HC_GOOGLE_CLIENT_ID (lo entrega el servicio web en /config.js);
## sin él, o fuera del navegador, no hay botón y el juego funciona igual con email.
class_name GoogleSignIn
extends RefCounted

## Tamaño del viewport del juego (project.godot), para pasar de coordenadas del juego a píxeles de la página.
const VIEW_W := 426.0
const VIEW_H := 240.0

const JS := """
(function () {
	if (window.hcGoogle) return;
	var g = window.hcGoogle = { cred: '', clientId: '', rect: null, el: null, loading: false, rendered: false };
	function place() {
		var c = document.querySelector('canvas');
		if (!g.el || !g.rect || !c) return;
		var b = c.getBoundingClientRect();
		var s = Math.min(b.width / %W%, b.height / %H%);
		var ox = b.left + (b.width - %W% * s) / 2;
		var oy = b.top + (b.height - %H% * s) / 2;
		g.el.style.left = (ox + g.rect.x * s) + 'px';
		g.el.style.top = (oy + g.rect.y * s) + 'px';
		g.el.style.width = (g.rect.w * s) + 'px';
		g.el.style.height = (g.rect.h * s) + 'px';
	}
	function render() {
		if (g.rendered || !window.google || !google.accounts) return;
		google.accounts.id.initialize({
			client_id: g.clientId,
			callback: function (r) { g.cred = r.credential || ''; }
		});
		google.accounts.id.renderButton(g.el, {
			type: 'standard', theme: 'filled_black', size: 'large',
			text: 'continue_with', shape: 'rectangular', locale: 'es', width: 300
		});
		g.rendered = true;
	}
	function load() {
		if (g.loading) return;
		g.loading = true;
		var s = document.createElement('script');
		s.src = 'https://accounts.google.com/gsi/client';
		s.async = true;
		s.onload = render;
		document.head.appendChild(s);
	}
	g.init = function (id) { g.clientId = id; };
	g.show = function (x, y, w, h) {
		if (!g.el) {
			g.el = document.createElement('div');
			g.el.style.cssText = 'position:fixed;z-index:10;display:flex;align-items:center;justify-content:center;overflow:hidden';
			document.body.appendChild(g.el);
			window.addEventListener('resize', place);
			load();
		}
		g.rect = { x: x, y: y, w: w, h: h };
		g.el.style.display = 'flex';
		place();
	};
	g.hide = function () { if (g.el) g.el.style.display = 'none'; };
	g.take = function () { var c = g.cred; g.cred = ''; return c; };
})();
"""

static var _started := false

## El Client ID de Google, o "" si no hay (fuera del navegador o sin configurar).
static func client_id() -> String:
	if not OS.has_feature("web"):
		return ""
	var v: Variant = JavaScriptBridge.eval("window.HC_GOOGLE_CLIENT_ID || ''")
	return v if v is String else ""

static func available() -> bool:
	return client_id() != ""

## Muestra el botón de Google ocupando `rect` (coordenadas del juego).
static func show(rect: Rect2) -> void:
	if not available():
		return
	if not _started:
		JavaScriptBridge.eval(JS.replace("%W%", str(VIEW_W)).replace("%H%", str(VIEW_H)))
		JavaScriptBridge.eval("window.hcGoogle.init(%s)" % JSON.stringify(client_id()))
		_started = true
	JavaScriptBridge.eval("window.hcGoogle.show(%d, %d, %d, %d)" % [rect.position.x, rect.position.y, rect.size.x, rect.size.y])

static func hide() -> void:
	if _started:
		JavaScriptBridge.eval("window.hcGoogle.hide()")

## El ID token si el jugador acaba de elegir cuenta; "" si no. Se consume al leerlo.
static func take_credential() -> String:
	if not _started:
		return ""
	var v: Variant = JavaScriptBridge.eval("window.hcGoogle.take()")
	return v if v is String else ""
