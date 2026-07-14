import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/device/zeppos/app_side/zeppos_app_side_storage.dart';

class ZeppOsAppSettingsService {
  ZeppOsAppSettingsService._() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static final instance = ZeppOsAppSettingsService._();
  static const _channel = MethodChannel('zerobox/zeppos_app_settings');
  final _storage = ZeppOsAppSideStorage();
  final _coordinator = ZeppOsSettingsCoordinator.instance;
  final _log = getLogger('ZeppOsAppSettings');
  final _origins = <int, Object>{};
  final _subscriptions = <int, StreamSubscription<ZeppOsSettingsChange>>{};

  Future<bool> canOpen(int appId) => _storage.settingExists(appId);

  Future<void> open(int appId, {String? title}) async {
    if (kIsWeb) {
      throw UnsupportedError('Web 平台暂不支持 Zepp OS 应用设置');
    }
    final script = await _storage.readSetting(appId);
    if (script == null) throw StateError('本地没有缓存 setting.js');
    final settings = await _coordinator.read(appId);
    final assets = await _storage.readSettingAssets(appId);
    final origin = Object();
    _origins[appId] = origin;
    await _subscriptions.remove(appId)?.cancel();
    _subscriptions[appId] = _coordinator
        .changesFor(appId)
        .where((change) => !identical(change.origin, origin))
        .listen((change) {
          _channel.invokeMethod<void>('settingsChanged', {
            'appId': appId,
            'settingsJson': jsonEncode(change.values),
          });
        });
    try {
      await _channel.invokeMethod<void>('open', {
        'appId': appId,
        'title': title ?? _appId(appId),
        'html': _runtimeHtml(script, settings, assets),
      });
    } on MissingPluginException {
      await _close(appId);
      throw UnsupportedError('当前平台暂不支持 Zepp OS 应用设置');
    } catch (_) {
      await _close(appId);
      rethrow;
    }
  }

  Future<Object?> _handleNativeCall(MethodCall call) async {
    var args = (call.arguments as Map?)?.cast<Object?, Object?>() ?? const {};
    var method = call.method;
    if (method == 'bridge') {
      final decoded = jsonDecode(args['message']?.toString() ?? '{}');
      if (decoded is! Map)
        throw const FormatException('Invalid bridge message');
      args = {...decoded, 'appId': args['appId']};
      method = args['type']?.toString() ?? '';
    }
    final appId = (args['appId'] as num?)?.toInt();
    if (appId == null || !_origins.containsKey(appId)) {
      throw PlatformException(code: 'INVALID_APP', message: 'Unknown appId');
    }
    switch (method) {
      case 'settings':
        final operation = args['operation']?.toString();
        final key = args['key']?.toString();
        final origin = _origins[appId];
        if (operation == 'set' && key != null) {
          await _coordinator.set(
            appId,
            key,
            args['value']?.toString() ?? '',
            origin: origin,
          );
        } else if (operation == 'remove' && key != null) {
          await _coordinator.remove(appId, key, origin: origin);
        } else if (operation == 'clear') {
          await _coordinator.clear(appId, origin: origin);
        } else {
          throw PlatformException(code: 'INVALID_OPERATION');
        }
      case 'log':
        _log.info('[${_appId(appId)} setting.js] ${args['message']}');
      case 'external':
        final uri = Uri.tryParse(args['url']?.toString() ?? '');
        if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
          throw PlatformException(code: 'INVALID_URL');
        }
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      case 'closed':
        await _close(appId);
      default:
        throw MissingPluginException();
    }
    return null;
  }

  Future<void> _close(int appId) async {
    _origins.remove(appId);
    await _subscriptions.remove(appId)?.cancel();
  }

  static String _appId(int value) =>
      '0x${value.toRadixString(16).padLeft(8, '0')}';
}

String _runtimeHtml(
  String source,
  Map<String, String> initialSettings,
  Map<String, Uint8List> assets,
) {
  final encodedSource = base64Encode(utf8.encode(source));
  final encodedSettings = base64Encode(
    utf8.encode(jsonEncode(initialSettings)),
  );
  final encodedAssets = jsonEncode({
    for (final entry in assets.entries)
      entry.key.replaceAll('\\', '/'): _dataUri(entry.key, entry.value),
  });
  return '''<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>:root{color-scheme:light dark;font:16px system-ui,sans-serif}body{margin:0;padding:20px;background:Canvas;color:CanvasText}.root{max-width:720px;margin:auto;display:flex;flex-direction:column;gap:12px}.section{padding:16px;border:1px solid color-mix(in srgb,CanvasText 20%,transparent);border-radius:16px}.section h2{font-size:18px;margin:0 0 4px}.section p{opacity:.7;margin:0 0 12px}.row{display:flex;align-items:center;gap:12px;min-height:44px}.row-main{display:flex;flex:1;flex-direction:column}.label{font-weight:600;margin-bottom:6px}.sublabel{opacity:.7;font-size:.9em}button,input,select,textarea{font:inherit;padding:10px 12px;border-radius:12px;border:1px solid color-mix(in srgb,CanvasText 30%,transparent)}button{cursor:pointer}img{max-width:100%}.error{white-space:pre-wrap;background:#b3261e;color:white;padding:16px;border-radius:12px}.toast{position:fixed;left:50%;transform:translateX(-50%);padding:12px 20px;border-radius:999px;background:#323232;color:white;z-index:10}.toast.top{top:24px}.toast.bottom{bottom:24px}</style></head><body><main id="root" class="root"></main><script>
'use strict';
const decode=s=>new TextDecoder().decode(Uint8Array.from(atob(s),c=>c.charCodeAt(0)));
const __source=decode('$encodedSource'),__values=new Map(Object.entries(JSON.parse(decode('$encodedSettings')))),__assets=$encodedAssets;
const post=message=>{const text=JSON.stringify(message);if(globalThis.ZeppSettingsBridge?.postMessage)ZeppSettingsBridge.postMessage(text);else if(globalThis.webkit?.messageHandlers?.ZeppSettingsBridge)webkit.messageHandlers.ZeppSettingsBridge.postMessage(text);else if(globalThis.chrome?.webview)chrome.webview.postMessage(text)};
const fmt=args=>args.map(v=>{try{return typeof v==='string'?v:JSON.stringify(v)}catch(_){return String(v)}}).join(' ');
globalThis.console={};for(const level of ['log','error','warn','info','debug'])console[level]=(...args)=>post({type:'log',level,message:fmt(args)});
const listeners=[];const settingsStorage={get length(){return __values.size},getItem(k){k=String(k);return __values.has(k)?__values.get(k):undefined},setItem(k,v){k=String(k);v=String(v);const oldValue=__values.get(k);__values.set(k,v);post({type:'settings',operation:'set',key:k,value:v});notify({key:k,oldValue,newValue:v})},removeItem(k){k=String(k);if(!__values.has(k))return;const oldValue=__values.get(k);__values.delete(k);post({type:'settings',operation:'remove',key:k});notify({key:k,oldValue,newValue:undefined})},clear(){const old=[...__values];__values.clear();post({type:'settings',operation:'clear'});for(const [key,oldValue] of old)notify({key,oldValue,newValue:undefined})},key(i){return [...__values.keys()][i]??null},toObject(){return Object.fromEntries(__values)},addListener(e,fn){if(e==='change'&&typeof fn==='function'&&!listeners.includes(fn))listeners.push(fn)},removeListener(e,fn){if(e==='change'){const i=listeners.indexOf(fn);if(i>=0)listeners.splice(i,1)}}};
function notify(change){for(const fn of [...listeners])try{fn(change)}catch(e){showError(e)}}
let pageOption;function AppSettingsPage(option){pageOption=option;rebuild()}globalThis.AppSettingsPage=AppSettingsPage;
function node(type,props={},children=[]){return{type,props:props||{},children:Array.isArray(children)?children:[children]}}for(const name of ['Auth','Button','Image','Link','Section','Select','Slider','Text','TextImageRow','TextInput','Toast','Toggle','View'])globalThis[name]=(props,children)=>node(name,props,children);
function apply(el,p){if(p.style&&typeof p.style==='object')Object.assign(el.style,p.style)}function textValue(c){return c.flat(Infinity).filter(v=>v!=null).map(String).join('')}function asset(value){if(!value)return'';const path=String(value).replace(/\\/g,'/').replace(/^\.\//,'');return __assets[path]||__assets[Object.keys(__assets).find(k=>k.endsWith('/'+path))]||value}function bound(p,fallback){return p.settingsKey&&__values.has(String(p.settingsKey))?__values.get(String(p.settingsKey)):p.value??fallback}function change(p,value){if(p.settingsKey)settingsStorage.setItem(String(p.settingsKey),Array.isArray(value)?JSON.stringify(value):String(value));if(typeof p.onChange==='function')p.onChange(value);queueMicrotask(rebuild)}function labeled(p,control){if(!p.label&&!p.title)return control;const row=document.createElement('label');row.className='row';const main=document.createElement('span');main.className='row-main';const label=document.createElement('span');label.className='label';label.textContent=p.label??p.title;main.append(label);if(p.sublabel){const sub=document.createElement('span');sub.className='sublabel';sub.textContent=p.sublabel;main.append(sub)}row.append(main,control);return row}
function render(item){if(item==null||item===false)return document.createTextNode('');if(typeof item==='string'||typeof item==='number')return document.createTextNode(String(item));if(Array.isArray(item)){const f=document.createDocumentFragment();item.forEach(x=>f.append(render(x)));return f}const p=item.props||{},c=item.children||[];let e;
switch(item.type){case'Text':e=document.createElement('span');e.textContent=p.text??p.label??textValue(c);break;case'Button':e=document.createElement('button');e.textContent=p.label??p.text??textValue(c);e.onclick=()=>p.onClick?.();break;case'View':e=document.createElement('div');e.onclick=()=>p.onClick?.();e.append(render(c));break;case'Section':e=document.createElement('section');e.className='section';if(p.title){const h=document.createElement('h2');h.textContent=p.title;e.append(h)}if(p.description){const d=document.createElement('p');d.textContent=p.description;e.append(d)}e.append(render(c));break;case'Image':e=document.createElement('img');e.src=asset(p.src??p.source);e.alt=p.alt??'';if(p.width)e.width=Number(p.width);if(p.height)e.height=Number(p.height);break;case'Link':e=document.createElement('a');e.href=p.source??'#';e.textContent=p.label??textValue(c)??p.source;e.onclick=ev=>{ev.preventDefault();post({type:'external',url:p.source})};break;case'Toggle':{const x=document.createElement('input');x.type='checkbox';x.checked=String(bound(p,false))==='true';x.onchange=()=>change(p,x.checked);e=labeled(p,x);if(c.length)e.prepend(render(c));break}case'TextInput':{const x=document.createElement(p.multiline?'textarea':'input');x.value=String(bound(p,''));x.placeholder=p.placeholder??'';x.disabled=!!p.disabled;if(p.rows)x.rows=Number(p.rows);x.onchange=()=>change(p,x.value);e=labeled(p,x);break}case'Slider':{const x=document.createElement('input');x.type='range';x.min=p.min??0;x.max=p.max??100;x.step=p.step??1;x.value=Number(bound(p,p.min??0));x.oninput=()=>change(p,Number(x.value));e=labeled(p,x);break}case'Select':{const x=document.createElement('select');x.multiple=!!p.multiple;for(const o of p.options||[]){const q=document.createElement('option');q.value=String(o.value);q.textContent=o.name??o.label??o.value;x.append(q)}let v=bound(p,p.multiple?[]:'');if(x.multiple){if(typeof v==='string')try{v=JSON.parse(v)}catch(_){v=v.split(',')}const a=Array.isArray(v)?v.map(String):[];for(const o of x.options)o.selected=a.includes(o.value)}else x.value=String(v);x.onchange=()=>change(p,x.multiple?[...x.selectedOptions].map(o=>o.value):x.value);e=labeled(p,x);break}case'Toast':e=document.createElement('div');e.className='toast '+(p.vertical==='bottom'?'bottom':'top');e.textContent=p.message??p.content??p.text??textValue(c);if(p.visible===false)e.hidden=true;if(p.visible!==false)setTimeout(()=>{e.remove();p.onClose?.()},p.duration??2000);break;case'TextImageRow':e=document.createElement('div');e.className='row';{const image=document.createElement('img');image.src=asset(p.icon);image.width=image.height=40;if(p.rounded)image.style.borderRadius='50%';const main=document.createElement('span');main.className='row-main';const label=document.createElement('span');label.textContent=p.label??'';main.append(label);if(p.sublabel){const sub=document.createElement('span');sub.className='sublabel';sub.textContent=p.sublabel;main.append(sub)}e.append(...(p.iconRight?[main,image]:[image,main]))}break;case'Auth':e=document.createElement('div');e.className='error';e.textContent='当前运行时不支持 OAuth Auth 组件';break;default:e=document.createElement('div');e.append(render(c))}apply(e,p);return e}
function showError(error){const root=document.getElementById('root');root.innerHTML='';const e=document.createElement('pre');e.className='error';e.textContent=String(error?.stack||error);root.append(e);post({type:'log',level:'error',message:e.textContent})}function rebuild(){if(!pageOption)return;try{const tree=pageOption.build.call(pageOption,{settingsStorage});document.getElementById('root').replaceChildren(render(tree))}catch(e){showError(e)}}
settingsStorage.addListener('change',rebuild);globalThis.eval=undefined;globalThis.Function=undefined;
try{const script=document.createElement('script');script.textContent=__source;document.head.append(script)}catch(e){showError(e)}
globalThis.__zeroboxSettingsChanged=raw=>{const next=typeof raw==='string'?JSON.parse(raw):raw;const old=new Map(__values);__values.clear();for(const [k,v] of Object.entries(next||{}))__values.set(k,String(v));for(const k of new Set([...old.keys(),...__values.keys()]))if(old.get(k)!==__values.get(k))notify({key:k,oldValue:old.get(k),newValue:__values.get(k)});rebuild()};
window.onerror=(m,s,l,c,e)=>{showError(e||new Error(String(m)));return true};window.onunhandledrejection=e=>showError(e.reason);
</script></body></html>''';
}

String _dataUri(String path, Uint8List bytes) {
  final extension = path.split('.').last.toLowerCase();
  final mime = switch (extension) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'svg' => 'image/svg+xml',
    _ => 'application/octet-stream',
  };
  return 'data:$mime;base64,${base64Encode(bytes)}';
}
