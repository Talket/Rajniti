'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {".git/COMMIT_EDITMSG": "1415de26a71e173764a7b53f01ab8159",
".git/config": "45ebf0b290d8e9fc044b5176107694da",
".git/description": "a0a7c3fff21f2aea3cfa1d0316dd816c",
".git/HEAD": "5ab7a4355e4c959b0c5c008f202f51ec",
".git/hooks/applypatch-msg.sample": "ce562e08d8098926a3862fc6e7905199",
".git/hooks/commit-msg.sample": "579a3c1e12a1e74a98169175fb913012",
".git/hooks/fsmonitor-watchman.sample": "a0b2633a2c8e97501610bd3f73da66fc",
".git/hooks/post-update.sample": "2b7ea5cee3c49ff53d41e00785eb974c",
".git/hooks/pre-applypatch.sample": "054f9ffb8bfe04a599751cc757226dda",
".git/hooks/pre-commit.sample": "5029bfab85b1c39281aa9697379ea444",
".git/hooks/pre-merge-commit.sample": "39cb268e2a85d436b9eb6f47614c3cbc",
".git/hooks/pre-push.sample": "2c642152299a94e05ea26eae11993b13",
".git/hooks/pre-rebase.sample": "56e45f2bcbc8226d2b4200f7c46371bf",
".git/hooks/pre-receive.sample": "2ad18ec82c20af7b5926ed9cea6aeedd",
".git/hooks/prepare-commit-msg.sample": "2b5c047bdb474555e1787db32b2d2fc5",
".git/hooks/push-to-checkout.sample": "c7ab00c7784efeadad3ae9b228d4b4db",
".git/hooks/sendemail-validate.sample": "4d67df3a8d5c98cb8565c07e42be0b04",
".git/hooks/update.sample": "647ae13c682f7827c22f5fc08a03674e",
".git/index": "05561132f70bef9f76dba04c63400794",
".git/info/exclude": "036208b4a1ab4a235d75c181e685e5a3",
".git/logs/HEAD": "a110013477897657eacc91129e68e554",
".git/logs/refs/heads/gh-pages": "dc9444a2fcca127e76cc8ba9e3b0c5c1",
".git/logs/refs/remotes/origin/gh-pages": "04492bfaacade8548add3eda9c264f3f",
".git/objects/03/2fe904174b32b7135766696dd37e9a95c1b4fd": "80ba3eb567ab1b2327a13096a62dd17e",
".git/objects/03/eaddffb9c0e55fb7b5f9b378d9134d8d75dd37": "87850ce0a3dd72f458581004b58ac0d6",
".git/objects/04/8b9fab431997ebcf8c197a6770c6218aecb9c8": "c4b2120b926404d816d72489886c2ca9",
".git/objects/0d/a2c9e57c962e52d718206d61f8e6133b6c449a": "bddbc8bc932e829d92b383b92f3c914d",
".git/objects/0e/03a67d69b259ec03876fd405dc6fbabf6316d9": "48c63d4dc5b304673a28e45011b0defc",
".git/objects/0f/11e2c43978105efb6b74950184a3736f9bb205": "28190fa04701ef2bef2ce8ece548bfca",
".git/objects/13/3cbb99bced289e322996b5df6aab3e01c569e8": "973bb14022352f8013d0b1e8b7507823",
".git/objects/1b/5cb2b7c4d47f8289e15311e9b6f6ce57673588": "b63af393fb5ffc904e283d394d2b6064",
".git/objects/23/05e529ae88cf5c3e640e77bb40d2ab2780947d": "7443474328dc50cfddee7609d91f6fe6",
".git/objects/27/36d07d898f3c422321312a4a4eee6f2b9e9383": "71423aa89a0f8afaa87d02386896f8d9",
".git/objects/32/81ecb0efc69661efea5406f19efee8165ff1ca": "4dfab71f1b7ae3765eeca6aedf1728a2",
".git/objects/33/31d9290f04df89cea3fb794306a371fcca1cd9": "e54527b2478950463abbc6b22442144e",
".git/objects/35/96d08a5b8c249a9ff1eb36682aee2a23e61bac": "e931dda039902c600d4ba7d954ff090f",
".git/objects/3d/ad212c946e25042d764b92974d014b32e7e712": "b95ae1823b4bb276303770d47552064f",
".git/objects/40/1184f2840fcfb39ffde5f2f82fe5957c37d6fa": "1ea653b99fd29cd15fcc068857a1dbb2",
".git/objects/42/794562136a31e388946c1bb499038dfd3f6c92": "1e81c9daa927742bf1cc492336408eb5",
".git/objects/46/4ab5882a2234c39b1a4dbad5feba0954478155": "2e52a767dc04391de7b4d0beb32e7fc4",
".git/objects/46/a4486333089e8d3ec517cee662247a5eb51ba0": "427cad7f66acfe006079cd6df05e692d",
".git/objects/4a/c3494e41dfdbd1c6e525f9b291c0a59484ace9": "bc739c689495d037b6381f5a6a2fbcd6",
".git/objects/4c/1cfb9e4382644cd4ae5f0a899ef8f07743de2e": "70ae0a8525a21c687da1aea54901e764",
".git/objects/4f/02e9875cb698379e68a23ba5d25625e0e2e4bc": "254bc336602c9480c293f5f1c64bb4c7",
".git/objects/50/bcdfc70b7a1c82aa992866f49b2ff1c5fbfe02": "bd9bf44db60cb3509fadd04349951578",
".git/objects/54/5cec8b5b6c46cb3414f0488e85947c022c1a0e": "0a51fc66a8c380484ecbac43d1c31d8d",
".git/objects/57/7946daf6467a3f0a883583abfb8f1e57c86b54": "846aff8094feabe0db132052fd10f62a",
".git/objects/58/3bdc056d29a003f8a8190510527fa8592ab148": "1a4ec6fa246fa8c99336f55ca4474655",
".git/objects/59/b16ecc1be7ca1240a39c8c0582218a5de905e2": "75fb5e9dc6bcba8afab14000c0810d2b",
".git/objects/5f/bf1f5ee49ba64ffa8e24e19c0231e22add1631": "f19d414bb2afb15ab9eb762fd11311d6",
".git/objects/64/25c3b725e113c9c2be82f916df2a3a3ace899f": "b4bd62aee52bb3624d3a28df3a59aa30",
".git/objects/64/5116c20530a7bd227658a3c51e004a3f0aefab": "f10b5403684ce7848d8165b3d1d5bbbe",
".git/objects/67/b73fc33ec427a2388f9fbc190820ebda8b7f42": "1439b52a3f6f71a4d7e1a31200a1d692",
".git/objects/69/dd618354fa4dade8a26e0fd18f5e87dd079236": "8cc17911af57a5f6dc0b9ee255bb1a93",
".git/objects/6b/9862a1351012dc0f337c9ee5067ed3dbfbb439": "85896cd5fba127825eb58df13dfac82b",
".git/objects/6f/b0ca3942b4df9855d304d346be4b3ccdc3f57f": "a2a1dead657013414bde087c5d2b311c",
".git/objects/71/7ae3ed47a6abc83555f8aed10fcded9fca6d94": "25f4ea0e54744da2d4cf738e0faee425",
".git/objects/77/26c2ca8ed6612952a962bf62fc9db449eaae96": "e9258980cbf0f8006240bc51c99ee883",
".git/objects/7a/3dee3a008ecaf48dd2fcef8d3bfc0bc179cd14": "d3ccb5995b8ef08c941ee9be697e29c5",
".git/objects/7f/90b5b0f54bde7a5952c346d5cf365e304144de": "6f9b0359b218aba4bfd1baef8559fdc1",
".git/objects/82/fadd7077347f1f2931d25a48242fd1603673f4": "a70bae10c134683d898c039c5f09e726",
".git/objects/84/374f30250424d506d4b1fceaa1e55ec89c025c": "8b8b598e63be649198fc937b00ffb4d2",
".git/objects/88/cfd48dff1169879ba46840804b412fe02fefd6": "e42aaae6a4cbfbc9f6326f1fa9e3380c",
".git/objects/8a/51a9b155d31c44b148d7e287fc2872e0cafd42": "9f785032380d7569e69b3d17172f64e8",
".git/objects/8a/aa46ac1ae21512746f852a42ba87e4165dfdd1": "1d8820d345e38b30de033aa4b5a23e7b",
".git/objects/8c/2df94811fffeffab9ef48d09db67a00732a153": "364c8b1b65ef48adef273d31771d67af",
".git/objects/8f/e7af5a3e840b75b70e59c3ffda1b58e84a5a1c": "e3695ae5742d7e56a9c696f82745288d",
".git/objects/8f/eaa0439d0c88e70cd6767aefc5fe950e10c61e": "f9b0d03bc905c96a695b3bf7e48bb619",
".git/objects/91/4a40ccb508c126fa995820d01ea15c69bb95f7": "8963a99a625c47f6cd41ba314ebd2488",
".git/objects/99/c2b67a9835c8cde43517d1ae31d68678aad4ed": "1cbdf02186bd6ea98a2eac979e6eae60",
".git/objects/a1/b607b364c212103ca88d671cfddb56fb12d390": "a16a4130771f88dfb15fcf64ee48f2e2",
".git/objects/a5/de584f4d25ef8aace1c5a0c190c3b31639895b": "9fbbb0db1824af504c56e5d959e1cdff",
".git/objects/a8/5d4a3ef3bf41d9ab88fff4b52b0c5cc581d4ce": "c31bdb95587866d81fa4c93121f6852e",
".git/objects/a8/8c9340e408fca6e68e2d6cd8363dccc2bd8642": "11e9d76ebfeb0c92c8dff256819c0796",
".git/objects/ac/0518257707a403f501e6218d21492c6795d01c": "ad990464d6a1d32d570d6380370a011b",
".git/objects/ac/4215d0d067fc8082a9488a682cee7b5966a673": "35a715a89b90358b19f6c38e9be014f6",
".git/objects/b7/49bfef07473333cf1dd31e9eed89862a5d52aa": "36b4020dca303986cad10924774fb5dc",
".git/objects/b9/2a0d854da9a8f73216c4a0ef07a0f0a44e4373": "f62d1eb7f51165e2a6d2ef1921f976f3",
".git/objects/bb/5f6f9d3674a98f273779bffc8b11c2502538fe": "510a6d7292c793ccb8ff81a0544045ca",
".git/objects/c2/b021b16c066ffa56d6e3968902341b5149b36a": "a1f2b4a2799bef3be5962ef8ed234b27",
".git/objects/c4/78727000e8cd794a5aef48597d7b158b2ab7ce": "e3ef28abfc76300ba61c3a3b2140ef5f",
".git/objects/d1/aae9cbc4a6fdc3300c468450217a0a79906d6c": "f03b846059bc02dfe943baed95141ce0",
".git/objects/d4/3532a2348cc9c26053ddb5802f0e5d4b8abc05": "3dad9b209346b1723bb2cc68e7e42a44",
".git/objects/d6/9c56691fbdb0b7efa65097c7cc1edac12a6d3e": "868ce37a3a78b0606713733248a2f579",
".git/objects/d7/7cfefdbe249b8bf90ce8244ed8fc1732fe8f73": "9c0876641083076714600718b0dab097",
".git/objects/d9/3952e90f26e65356f31c60fc394efb26313167": "1401847c6f090e48e83740a00be1c303",
".git/objects/df/7b40b2bb3fec77b529d6140ed3265490c147cd": "c9308dfd5707ad92709d9299d8952bfc",
".git/objects/e9/94225c71c957162e2dcc06abe8295e482f93a2": "2eed33506ed70a5848a0b06f5b754f2c",
".git/objects/eb/9b4d76e525556d5d89141648c724331630325d": "37c0954235cbe27c4d93e74fe9a578ef",
".git/objects/ec/416a3157e8098493d1aa6caaa237a57ed23b67": "dc79d2a1bd0bb164798a33050702b242",
".git/objects/ef/1bdfea2d6ffc67a31f8670cb9453d5ef4a1def": "c1a5af7c7dbbc48952fb6e2a67d1f7c8",
".git/objects/ef/36c3ca3fc503462b204bba389d1314cb1b5721": "265e5a32ee0462ad3814c6935a6b806d",
".git/objects/ef/a3ea885a1e749ce565d4ba20e91c2ff07be438": "84ee7376b12f4fb82b6cf6779fbf3d77",
".git/objects/ef/b875788e4094f6091d9caa43e35c77640aaf21": "27e32738aea45acd66b98d36fc9fc9e0",
".git/objects/f1/fc2c09da778bd649390bf2b52bf231c1af15a3": "0af05b9641e6c865703a676fa66d9fc7",
".git/objects/f2/04823a42f2d890f945f70d88b8e2d921c6ae26": "6b47f314ffc35cf6a1ced3208ecc857d",
".git/objects/f2/805b13fe31520955d2d2f5b43d19f093568753": "f140141efbce7d5097d28ec716c655b4",
".git/objects/f3/709a83aedf1f03d6e04459831b12355a9b9ef1": "538d2edfa707ca92ed0b867d6c3903d1",
".git/objects/f5/72b90ef57ee79b82dd846c6871359a7cb10404": "e68f5265f0bb82d792ff536dcb99d803",
".git/objects/fe/6fb3c12273bdc1c6e29442323c8fac3767433b": "1869871914c9486c87af871484aa4b5b",
".git/refs/heads/gh-pages": "e37ba30f52310bc2f2ff8b17fb1c5b18",
".git/refs/remotes/origin/gh-pages": "884785c135050c29d67ecc050cc3dbd2",
"assets/AssetManifest.bin": "693635b5258fe5f1cda720cf224f158c",
"assets/AssetManifest.bin.json": "69a99f98c8b1fb8111c5fb961769fcd8",
"assets/AssetManifest.json": "2efbb41d7877d10aac9d091f58ccd7b9",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "82f8624c3ab60db9e65a2e18069c5d09",
"assets/NOTICES": "cce52342dd9e671ae0c2b4bc548c9612",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "86e461cf471c1640fd2b461ece4589df",
"canvaskit/canvaskit.js.symbols": "68eb703b9a609baef8ee0e413b442f33",
"canvaskit/canvaskit.wasm": "efeeba7dcc952dae57870d4df3111fad",
"canvaskit/chromium/canvaskit.js": "34beda9f39eb7d992d46125ca868dc61",
"canvaskit/chromium/canvaskit.js.symbols": "5a23598a2a8efd18ec3b60de5d28af8f",
"canvaskit/chromium/canvaskit.wasm": "64a386c87532ae52ae041d18a32a3635",
"canvaskit/skwasm.js": "f2ad9363618c5f62e813740099a80e63",
"canvaskit/skwasm.js.symbols": "80806576fa1056b43dd6d0b445b4b6f7",
"canvaskit/skwasm.wasm": "f0dfd99007f989368db17c9abeed5a49",
"canvaskit/skwasm_st.js": "d1326ceef381ad382ab492ba5d96f04d",
"canvaskit/skwasm_st.js.symbols": "c7e7aac7cd8b612defd62b43e3050bdd",
"canvaskit/skwasm_st.wasm": "56c3973560dfcbf28ce47cebe40f3206",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "76f08d47ff9f5715220992f993002504",
"flutter_bootstrap.js": "1844b5adbe67c6eaa30530c8f131136b",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "924cfc1c6e8a509588238846aed159ef",
"/": "924cfc1c6e8a509588238846aed159ef",
"main.dart.js": "841992bd21d967a1509890300eda938c",
"manifest.json": "2012be2534441c98e9bdeef40c6f72a6",
"version.json": "654166a1bd3bf15e1fb644ee965f4991"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
