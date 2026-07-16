export const HUD_COMPACT_WIDTH = 520;
export const MOBILE_TOPBAR_WIDTH = 171;
export const DESKTOP_TICKER_INSET = 80;

const finiteSize = value => Number.isFinite(value) ? Math.max(0, value) : 0;
const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

export function resolvePresentationLayout(stageWidth, stageHeight, mobileChrome=false) {
  const stageW=finiteSize(stageWidth),stageH=finiteSize(stageHeight);
  const gameW=Math.min(stageW,stageH*4/3),gameH=Math.min(stageH,stageW*3/4);
  const gameLeft=(stageW-gameW)/2,gameTop=(stageH-gameH)/2;
  const scale=gameW/800;
  const inset=clamp(8*scale,4,8),gap=clamp(8*scale,4,8);
  const topInset=clamp(26*scale,8,26),fontSize=clamp(11*scale,8,11);
  const hudWidth=Math.max(0,gameW-inset*2),columnWidth=Math.max(0,(hudWidth-gap)/2);
  const topbarWidth=Math.min(MOBILE_TOPBAR_WIDTH,stageW*.52);
  const tickerInset=mobileChrome?topbarWidth:Math.min(DESKTOP_TICKER_INSET,stageW);
  return {
    stage:{w:stageW,h:stageH},
    game:{x:gameLeft,y:gameTop,w:gameW,h:gameH},
    hud:{
      x:gameLeft+inset,y:gameTop+topInset,w:hudWidth,
      right:stageW-gameLeft-gameW+inset,gap,columnWidth,fontSize,
      compact:gameW<=HUD_COMPACT_WIDTH,
    },
    topbar:{x:stageW-topbarWidth,y:0,w:topbarWidth,h:20},
    ticker:{x:0,y:0,w:Math.max(0,stageW-tickerInset),h:18,right:tickerInset},
  };
}
