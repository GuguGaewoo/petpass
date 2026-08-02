// 네이버 지도 JS v3 래퍼.
//
// Dart 에서 지도 API 를 직접 호출하면 js_interop 선언이 장황해진다.
// JS 는 JS 에 두고 Dart 는 함수 두 개만 부른다.
window.petpassMap = {
  _loading: null,

  // 스크립트를 한 번만 불러온다. 여러 지도를 띄워도 중복 로드하지 않는다.
  load(keyId) {
    if (window.naver && window.naver.maps) return Promise.resolve();
    if (this._loading) return this._loading;

    this._loading = new Promise((resolve, reject) => {
      const s = document.createElement('script');
      // 파라미터 이름이 ncpKeyId 로 바뀌었다. 문서에 따라 ncpClientId 로
      // 나온 곳도 있으니, 인증 실패가 나면 그쪽으로 바꿔볼 것.
      s.src = 'https://oapi.map.naver.com/openapi/v3/maps.js?ncpKeyId=' + keyId;
      s.onload = () => resolve();
      s.onerror = () => reject(new Error('네이버 지도 스크립트 로드 실패'));
      document.head.appendChild(s);
    });
    return this._loading;
  },

  // elId 요소에 지도를 그린다.
  render(elId, lat, lng, zoom, pinsJson, onTap) {
    const el = document.getElementById(elId);
    if (!el) return;

    const map = new naver.maps.Map(el, {
      center: new naver.maps.LatLng(lat, lng),
      zoom: zoom,
      // 좌표를 외부로 보내는 기능은 쓰지 않는다. 지도 표시 전용이다.
      mapDataControl: false,
      scaleControl: true,
      logoControl: true,
    });

    const pins = JSON.parse(pinsJson);
    for (const p of pins) {
      const marker = new naver.maps.Marker({
        position: new naver.maps.LatLng(p.lat, p.lng),
        map: map,
        title: p.title,
        icon: {
          content:
            '<div style="width:14px;height:14px;border-radius:50%;' +
            'background:' + p.color + ';border:2px solid #fff;' +
            'box-shadow:0 1px 3px rgba(0,0,0,.4)"></div>',
          anchor: new naver.maps.Point(7, 7),
        },
      });
      if (onTap) {
        naver.maps.Event.addListener(marker, 'click', () => onTap(p.id));
      }
    }
  },
};
