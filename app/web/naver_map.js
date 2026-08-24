// 네이버 지도 JS v3 래퍼.
//
// Dart 에서 지도 API 를 직접 호출하면 js_interop 선언이 장황해진다.
// JS 는 JS 에 두고 Dart 는 함수 두 개만 부른다.
window.petpassMap = {
  _loading: null,

  // elId -> 지도 인스턴스. 화면을 떠날 때 파기하기 위해 보관한다.
  _maps: {},

  // 스크립트를 한 번만 불러온다. 여러 지도를 띄워도 중복 로드하지 않는다.
  load(keyId) {
    if (window.naver && window.naver.maps) return Promise.resolve();
    if (this._loading) return this._loading;

    this._loading = new Promise((resolve, reject) => {
      const s = document.createElement('script');
      s.src = 'https://oapi.map.naver.com/openapi/v3/maps.js?ncpKeyId=' + keyId;
      s.onload = () => resolve();
      s.onerror = () => reject(new Error('네이버 지도 스크립트 로드 실패'));
      document.head.appendChild(s);
    });
    return this._loading;
  },

  // elId 요소에 지도를 그린다.
  // 화면을 떠날 때 호출한다. 지도 인스턴스가 쌓이면 메모리를 먹는다.
  destroy(elId) {
    const map = this._maps[elId];
    if (map) {
      map.destroy();
      delete this._maps[elId];
    }
  },

  render(elId, lat, lng, zoom, pinsJson, onTap) {
    const el = document.getElementById(elId);
    if (!el) return;

    if (this._maps[elId]) this._maps[elId].destroy();

    const map = new naver.maps.Map(el, {
      center: new naver.maps.LatLng(lat, lng),
      zoom: zoom,
      // 좌표를 외부로 보내는 기능은 쓰지 않는다. 지도 표시 전용이다.
      mapDataControl: false,
      // 페이지 스크롤 중 지도 위를 지나면 휠이 확대로 먹힌다.
      // 상세 화면의 지도는 위치 확인용이므로 확대를 막는다.
      scrollWheel: false,
      pinchZoom: false,
      scaleControl: true,
      logoControl: true,
    });

    this._maps[elId] = map;

    const pins = JSON.parse(pinsJson);
    const bounds = pins.length > 1 ? new naver.maps.LatLngBounds() : null;

    for (const p of pins) {
      const pos = new naver.maps.LatLng(p.lat, p.lng);
      if (bounds) bounds.extend(pos);

      // 기준 장소는 물방울 모양으로 크게, 주변은 작은 점.
      // 색은 판정 등급을 나타내므로 형태로 구분한다.
      // 기준 장소를 빨강으로 칠하면 '불가' 판정과 같은 색이 되어 오독된다.
      const html = p.origin
        ? '<div style="width:26px;height:26px;border-radius:50% 50% 50% 0;' +
          'transform:rotate(-45deg);background:' + p.color + ';' +
          'border:3px solid #fff;box-shadow:0 2px 6px rgba(0,0,0,.4)"></div>'
        : '<div style="width:14px;height:14px;border-radius:50%;' +
          'background:' + p.color + ';border:2px solid #fff;' +
          'box-shadow:0 1px 3px rgba(0,0,0,.4)"></div>';

      // 물방울은 뾰족한 끝이 좌표를 가리키도록 앵커를 아래로 둔다
      const ax = p.origin ? 13 : 7;
      const ay = p.origin ? 26 : 7;

      const marker = new naver.maps.Marker({
        position: pos,
        map: map,
        title: p.title,
        // 기준 장소를 위에 그려 주변 마커에 가려지지 않게 한다
        zIndex: p.origin ? 100 : 1,
        icon: {
          content: html,
          anchor: new naver.maps.Point(ax, ay),
        },
      });

      if (onTap && !p.origin) {
        naver.maps.Event.addListener(marker, 'click', () => onTap(p.id));
      }
    }

    // 마커가 여러 개면 전부 보이도록 화면을 맞춘다.
    if (bounds) {
      map.fitBounds(bounds, { top: 40, right: 40, bottom: 40, left: 40 });
    }
  },
};
