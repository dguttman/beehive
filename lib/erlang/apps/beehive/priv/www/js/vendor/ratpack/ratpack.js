// LAB.js (LABjs :: Loading And Blocking JavaScript)
// v1.0.2rc1 (c) Kyle Simpson
// MIT License
// LAB.js (LABjs :: Loading And Blocking JavaScript) | v1.0.2rc1 (c) Kyle Simpson | MIT License
(function(j){var p="string",w="head",H="body",Y="script",t="readyState",k="preloaddone",y="loadtrigger",I="srcuri",D="preload",Z="complete",z="done",A="which",J="preserve",E="onreadystatechange",ba="onload",K="hasOwnProperty",bb="script/cache",L="[object ",bv=L+"Function]",bw=L+"Array]",e=null,h=true,i=false,s=j.document,bx=j.location,bc=j.ActiveXObject,B=j.setTimeout,bd=j.clearTimeout,M=function(a){return s.getElementsByTagName(a)},N=Object.prototype.toString,O=function(){},q={},P={},be=/^[^?#]*\//.exec(bx.href)[0],bf=/^\w+\:\/\/\/?[^\/]+/.exec(be)[0],by=M(Y),bg=j.opera&&N.call(j.opera)==L+"Opera]",bh=(function(a){a[a]=a+"";return a[a]!=a+""})(new String("__count__")),u={cache:!(bh||bg),order:bh||bg,xhr:h,dupe:h,base:"",which:w};u[J]=i;u[D]=h;q[w]=M(w);q[H]=M(H);function Q(a){return N.call(a)===bv}function R(a,b){var c=/^\w+\:\/\//,d;if(typeof a!==p)a="";if(typeof b!==p)b="";d=(c.test(a)?"":b)+a;return((c.test(d)?"":(d.charAt(0)==="/"?bf:be))+d)}function bz(a){return(R(a).indexOf(bf)===0)}function bA(a){var b,c=-1;while(b=by[++c]){if(typeof b.src===p&&a===R(b.src)&&b.type!==bb)return h}return i}function F(v,l){v=!(!v);if(l==e)l=u;var bi=i,C=v&&l[D],bj=C&&l.cache,G=C&&l.order,bk=C&&l.xhr,bB=l[J],bC=l.which,bD=l.base,bl=O,S=i,x,r=h,m={},T=[],U=e;C=bj||bk||G;function bm(a,b){if((a[t]&&a[t]!==Z&&a[t]!=="loaded")||b[z]){return i}a[ba]=a[E]=e;return h}function V(a,b,c){c=!(!c);if(!c&&!(bm(a,b)))return;b[z]=h;for(var d in m){if(m[K](d)&&!(m[d][z]))return}bi=h;bl()}function bn(a){if(Q(a[y])){a[y]();a[y]=e}}function bE(a,b){if(!bm(a,b))return;b[k]=h;B(function(){q[b[A]].removeChild(a);bn(b)},0)}function bF(a,b){if(a[t]===4){a[E]=O;b[k]=h;B(function(){bn(b)},0)}}function W(b,c,d,g,f,n){var o=b[A];B(function(){if("item"in q[o]){if(!q[o][0]){B(arguments.callee,25);return}q[o]=q[o][0]}var a=s.createElement(Y);a.type=d;if(typeof g===p)a.charset=g;if(Q(f)){a[ba]=a[E]=function(){f(a,b)};a.src=c}q[o].insertBefore(a,(o===w?q[o].firstChild:e));if(typeof n===p){a.text=n;V(a,b,h)}},0)}function bo(a,b,c,d){P[a[I]]=h;W(a,b,c,d,V)}function bp(a,b,c,d){var g=arguments;if(r&&a[k]==e){a[k]=i;W(a,b,bb,d,bE)}else if(!r&&a[k]!=e&&!a[k]){a[y]=function(){bp.apply(e,g)}}else if(!r){bo.apply(e,g)}}function bq(a,b,c,d){var g=arguments,f;if(r&&a[k]==e){a[k]=i;f=a.xhr=(bc?new bc("Microsoft.XMLHTTP"):new j.XMLHttpRequest());f[E]=function(){bF(f,a)};f.open("GET",b);f.send("")}else if(!r&&a[k]!=e&&!a[k]){a[y]=function(){bq.apply(e,g)}}else if(!r){P[a[I]]=h;W(a,b,c,d,e,a.xhr.responseText);a.xhr=e}}function br(a){if(a.allowDup==e)a.allowDup=l.dupe;var b=a.src,c=a.type,d=a.charset,g=a.allowDup,f=R(b,bD),n,o=bz(f);if(typeof c!==p)c="text/javascript";if(typeof d!==p)d=e;g=!(!g);if(!g&&((P[f]!=e)||(r&&m[f])||bA(f))){if(m[f]!=e&&m[f][k]&&!m[f][z]&&o){V(e,m[f],h)}return}if(m[f]==e)m[f]={};n=m[f];if(n[A]==e)n[A]=bC;n[z]=i;n[I]=f;S=h;if(!G&&bk&&o)bq(n,f,c,d);else if(!G&&bj)bp(n,f,c,d);else bo(n,f,c,d)}function bs(a){T.push(a)}function X(a){if(v&&!G)bs(a);if(!v||C)a()}function bt(a){var b=[],c;for(c=-1;++c<a.length;){if(N.call(a[c])===bw)b=b.concat(bt(a[c]));else b[b.length]=a[c]}return b}x={script:function(){bd(U);var a=bt(arguments),b=x,c;if(bB){for(c=-1;++c<a.length;){if(c===0){X(function(){br((typeof a[0]===p)?{src:a[0]}:a[0])})}else b=b.script(a[c]);b=b.wait()}}else{X(function(){for(c=-1;++c<a.length;){br((typeof a[c]===p)?{src:a[c]}:a[c])}})}U=B(function(){r=i},5);return b},wait:function(a){bd(U);r=i;if(!Q(a))a=O;var b=F(h,l),c=b.trigger,d=function(){try{a()}catch(err){}c()};delete b.trigger;var g=function(){if(S&&!bi)bl=d;else d()};if(v&&!S)bs(g);else X(g);return b}};x.block=x.wait;if(v){x.trigger=function(){var a,b=-1;while(a=T[++b])a();T=[]}}return x}function bu(a){var b,c={},d={"UseCachePreload":"cache","UseLocalXHR":"xhr","UsePreloading":D,"AlwaysPreserveOrder":J,"AllowDuplicates":"dupe"},g={"AppendTo":A,"BasePath":"base"};for(b in d)g[b]=d[b];c.order=!(!u.order);for(b in g){if(g[K](b)&&u[g[b]]!=e)c[g[b]]=(a[b]!=e)?a[b]:u[g[b]]}for(b in d){if(d[K](b))c[d[b]]=!(!c[d[b]])}if(!c[D])c.cache=c.order=c.xhr=i;c.which=(c.which===w||c.which===H)?c.which:w;return c}j.$LAB={setGlobalDefaults:function(a){u=bu(a)},setOptions:function(a){return F(i,bu(a))},script:function(){return F().script.apply(e,arguments)},wait:function(){return F().wait.apply(e,arguments)}};j.$LAB.block=j.$LAB.wait;(function(a,b,c){if(s[t]==e&&s[a]){s[t]="loading";s[a](b,c=function(){s.removeEventListener(b,c,i);s[t]=Z},i)}})("addEventListener","DOMContentLoaded")})(window);

// name: RatPack
// version: 0.0.1

var RatPack;

RatPack = function(opts){
  RatPack.to_use = ["ratpack_controller"];
  RatPack.to_load = ["/js/vendor/ratpack/ratpack_controller.js"];
    
  RatPack.plugins(opts.plugins);
  RatPack.controllers(opts.controllers);
  
  return RatPack;
};

RatPack.plugins = function(plugins) {
  RatPack._load("/js/vendor/sammy/plugins/sammy.", "", plugins, function(m) {
    return "Sammy." + m.replace(/^\w/, function($0) { return $0.toUpperCase(); });
  });
};

RatPack.controllers = function(controllers) {
  RatPack._load("/js/controllers/", "_controller", controllers, function(m) {return m;});
};

RatPack._load = function(path, tail, array, modifier) {
  for (var i = array.length - 1; i >= 0; i--){
    var fullpath = path + array[i] + tail + ".js";
    var name = modifier(array[i] + tail);
    
    RatPack.to_load.push(fullpath);
    RatPack.to_use.push(name);
  };
};

RatPack.run = function(default_path) {
  RatPack.app = $.sammy(function() {
    $LAB.script(RatPack.to_load).wait( function() {
      for (var i = RatPack.to_use.length - 1; i >= 0; i--){
        var name = RatPack.to_use[i];
        RatPack.app.use(eval(name));
      };
      
      RatPack.app.run(default_path || "#/");
    });
  });

};
  
// Bundle jQuery and Sammy, then load the app
$LAB
  .script("/js/vendor/jquery/jquery-1.4.2.min.js").wait()
  .script("/js/vendor/sammy/sammy.js").wait()
  .script("/js/app.js");
