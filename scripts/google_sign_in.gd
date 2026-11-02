## Puente con Google Identity Services (solo en la versión web del juego).
## El botón oficial de Google es un elemento HTML: se coloca encima del canvas, invisible y
## estirado sobre el botón arcade CONTINUAR CON GOOGLE de la pantalla de Login, que es lo que se ve. Al elegir cuenta, Google entrega un ID token
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
	var g = window.hcGoogle = { cred: '', clientId: '', rect: null, el: null, loading: false, rendered: false, hover: false };
	function place() {
		var c = document.querySelector('canvas');
		if (!g.el || !g.rect || !c) return;
		var b = c.getBoundingClientRect();
		var s = Math.min(b.width / %W%, b.height / %H%);
		var ox = b.left + (b.width - %W% * s) / 2;
		var oy = b.top + (b.height - %H% * s) / 2;
		var w = g.rect.w * s, h = g.rect.h * s;
		g.el.style.left = (ox + g.rect.x * s) + 'px';
		g.el.style.top = (oy + g.rect.y * s) + 'px';
		g.el.style.width = w + 'px';
		g.el.style.height = h + 'px';
		// El botón de Google se estira para cubrir todo el botón arcade que tiene debajo.
		var btn = g.el.firstElementChild;
		if (!btn || !btn.offsetWidth || !btn.offsetHeight) return;
		btn.style.transformOrigin = '0 0';
		btn.style.transform = 'scale(' + (w / btn.offsetWidth) + ',' + (h / btn.offsetHeight) + ')';
	}
	function render() {
		if (g.rendered || !window.google || !google.accounts) return;
		google.accounts.id.initialize({
			client_id: g.clientId,
			callback: function (r) { g.cred = r.credential || ''; }
		});
		google.accounts.id.renderButton(g.el, {
			type: 'standard', theme: 'filled_black', size: 'large',
			text: 'continue_with', shape: 'rectangular', locale: 'es', width: 400
		});
		g.rendered = true;
		// Google dibuja su botón un poco después; se reajusta cuando ya tiene tamaño.
		new ResizeObserver(place).observe(g.el.firstElementChild || g.el);
		setTimeout(place, 300);
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
			// Invisible pero clicable: lo que se ve es el botón arcade del juego, debajo.
			g.el.style.cssText = 'position:fixed;z-index:10;overflow:hidden;opacity:0.0001;cursor:pointer';
			g.el.addEventListener('mouseenter', function () { g.hover = true; });
			g.el.addEventListener('mouseleave', function () { g.hover = false; });
			document.body.appendChild(g.el);
			window.addEventListener('resize', place);
			load();
		}
		g.rect = { x: x, y: y, w: w, h: h };
		g.el.style.display = 'flex';
		place();
	};
	g.hide = function () { if (g.el) { g.el.style.display = 'none'; g.hover = false; } };
	// Con teclado/mando no se puede hacer clic en el botón de Google: se abre el selector de cuentas.
	g.prompt = function () { if (g.rendered) google.accounts.id.prompt(); };
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

## Si el ratón está sobre el botón (el canvas no recibe el ratón mientras el botón HTML lo tapa).
static func hovered() -> bool:
	if not _started:
		return false
	return JavaScriptBridge.eval("window.hcGoogle.hover") == true

## Abre el selector de cuentas de Google sin clic (para teclado o mando).
static func prompt() -> void:
	if _started:
		JavaScriptBridge.eval("window.hcGoogle.prompt()")

## El ID token si el jugador acaba de elegir cuenta; "" si no. Se consume al leerlo.
static func take_credential() -> String:
	if not _started:
		return ""
	var v: Variant = JavaScriptBridge.eval("window.hcGoogle.take()")
	return v if v is String else ""
