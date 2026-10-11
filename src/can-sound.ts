let context: AudioContext | undefined;

// Unlock audio during the tap, before waiting for the saved entry.
// Sound is optional: browser/audio errors must never prevent a check-in.
export function prepareCanSound(): () => void {
 try {
  const Audio = window.AudioContext || (window as unknown as {webkitAudioContext?: typeof AudioContext}).webkitAudioContext;
  if (!Audio) return () => {};
  if (!context || context.state === 'closed') context = new Audio();
  const ctx = context;
  void ctx.resume().catch(() => {});
  let played = false;
  return () => {
   if (played || ctx.state !== 'running') return;
   played = true;
   try {
    const rate = ctx.sampleRate;
    const buffer = ctx.createBuffer(1, Math.ceil(rate * .65), rate);
    const samples = buffer.getChannelData(0);
    let previousNoise = 0;
    for (let i = 0; i < samples.length; i++) {
     const t = i / rate;
     const noise = Math.random() * 2 - 1;
     const highNoise = (noise - previousNoise) * .5;
     previousNoise = noise;
     // Pull-tab click, opening pop, then escaping carbonation.
     let value = .60 * Math.exp(-t * 95) * (Math.sin(2*Math.PI*2100*t) + .45*Math.sin(2*Math.PI*3700*t));
     if (t >= .065) {
      const p = t - .065;
      // A torn metal seal: broadband crack and short, inharmonic tab resonances.
      // Avoid the low, hollow tone that sounds like a bottle cork.
      value += .64 * Math.exp(-p * 60) * highNoise;
      value += Math.exp(-p * 85) * (.17*Math.sin(2*Math.PI*1750*p) + .10*Math.sin(2*Math.PI*3190*p));
     }
     if (t >= .085) {
      const p = t - .085;
      value += .23 * Math.min(1, p/.008) * Math.exp(-p * 10) * highNoise;
     }
     samples[i] = value * Math.min(1, (samples.length-i)/(rate*.015));
    }
    const source = ctx.createBufferSource();
    source.buffer = buffer;
    source.connect(ctx.destination);
    source.onended = () => source.disconnect();
    source.start();
   } catch { /* Check-in remains successful without audio. */ }
  };
 } catch { return () => {}; }
}
