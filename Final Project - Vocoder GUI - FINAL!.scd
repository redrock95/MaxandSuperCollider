//s.options.numAudioBusChannels;
s.options.numOutputBusChannels = 20;
//s.options.numInputBusChannels;

Server.default.options.device = "JackRouter";
Server.default.options.device = "UMC404HD 192k";
Server.default.options.device = "Built-in Output";

Server.default.options.device;

//Final Project!!!

//Vocoder with Gui controlled input/output gains, and effects

//Thought Process, general progress, and Steps:
//1:Make synth def for vocoder-complete, delay and reverb-complete
//2:Make MIDI information play polyphonic vocoder-complete
//3:Make GUI window with 5 sliders, text boxes for each, knobs below sliders, and a button to initiate vocoder-complete. *Edit* switched to reverb, dry mic, delay and free all buttons-complete.
//4:Make Buttons for reverb, delay, and a free all button - complete
//5:make button actions correspond with turning on reverb, delay, mic, and free all-pending. Reverb and Delay buttons not working for some reason.
//6:Make each slider correspond to wet signal of vocoder, output of dry mic-complete
//reverb sends, and delay sends-complete!
//Make Knobs for effect levels (ex: delay time, mix, etc)- complete
//Make Knob action follow control spec for specific effect levels-pending



------------------------------------------------------------------------------------------------------------------------------
//Synth Defs

(
SynthDef(\soundIn, {
	arg channelBus, aux1SendBus, aux2SendBus, amp=0.5,
	    aux1Level=1, aux2Level=1;

	var input;
	input = SoundIn.ar(0) * amp;
	Out.ar(channelBus, input);
	Out.ar(aux1SendBus, (input * aux1Level));
	Out.ar(aux2SendBus, (input * aux2Level));
}).add;



SynthDef(\vocode,{arg freq=200, voiced=0.7, amp=16, gate=1, wet=1.0, aux1SendBus, aux2SendBus, aux1Level=1, aux2Level=1,  channelBus=0, amp2=5;
var centrefreqs, amps, bandwidths, rq; //data for formants
var analysissignal, synthesissignal, periodicsource, aperiodicsource;
var analysisfilters, synthesisfilters;
var env, envgen;
var numFilters=40;
var analysisfiltersEF, analysisfiltersBlend, ampAnalysisPercent=0.5, envFollowPercent=0.5;
var dry, drySignal, wetSignal, wetDryMix, output;
dry = 1.0 - wet;//this needs to be controlled arg;

// Create an envelope to smoothly enter and exit the sound
env = Env.adsr();
envgen = EnvGen.ar(env, gate: gate, doneAction:2);

// Create an array of frequencies for the bandpass filter
centrefreqs= (1..numFilters)*freq; //choose centre frequencies
// amps= (0.dup(numFilters)).dbamp;

// each bandwidth for each filter should be unique
bandwidths= (freq*0.1).dup(numFilters); //  //bandwidths
rq= bandwidths/centrefreqs;	//reciprocal of q; bandwidth/centrefreq

analysissignal= In.ar(channelBus, 1) * amp2; //analyze audio input on machine the number should be arg
analysissignal = HPF.ar(analysissignal, 1000);
analysissignal = Compander.ar(analysissignal, analysissignal, -20.dbamp, 1, 0.1);
periodicsource=Saw.ar(freq);//maybe amp arg?

//pink noise drops off as frequency increases at -dB per octave,
aperiodicsource= PinkNoise.ar(0.7);

//take now as mixture of periodic and aperiodic
synthesissignal= (voiced*periodicsource)+((1.0-voiced)*aperiodicsource);

//do the analysis in the specified bands, finding the amplitude in each band
analysisfilters = Amplitude.kr(BPF.ar(analysissignal, centrefreqs, rq));
analysisfilters = OnePole.kr(analysisfilters);

analysisfiltersEF = EnvFollow.kr(BPF.ar(analysissignal, centrefreqs, rq));
analysisfiltersBlend = (analysisfilters * ampAnalysisPercent) + (analysisfiltersEF * envFollowPercent);

//modulate bandwise the resynthesis
synthesisfilters = analysisfiltersBlend*BPF.ar(synthesissignal, centrefreqs, rq);
synthesisfilters = Compander.ar(synthesisfilters, synthesisfilters, 0.1, 1, 0.01);
synthesisfilters = Compander.ar(synthesisfilters, synthesisfilters, 0.1, 0.9, 1);
//synthesisfilters = Compander.ar(synthesisfilters, synthesisfilters, 0.1, 1.2, 1);
//synthesisfilters = LPF.ar(synthesisfilters, 12000);
drySignal = analysissignal;
wetSignal = Mix.ar(synthesisfilters);
wetDryMix = (drySignal*dry) + (wetSignal * wet);
//amp compensates for energy lost by filters
output = (envgen*amp*wetDryMix);
Out.ar(channelBus, output);
Out.ar(aux1SendBus, output * aux1Level);
Out.ar(aux2SendBus, output * aux2Level);


}).add;



SynthDef(\reverb,
	ugenGraphFunc: {arg aux1SendBus, aux1Level=0, aux2SendBus, aux2Level=0, aux1ReturnBus, mix=0.33, room=1.0, damp=0.5, wet=1, gate=1, channelBus=0;
		var dry, input, reverb, output, env, envGen;
		dry = 1.0 - wet;
		input = In.ar(aux1SendBus, 1);
		reverb = FreeVerb.ar(
			in: input,
			mix: mix,
			room: room,
			damp: damp)!2;
		env = Env.adsr();
		envGen = EnvGen.ar(env, gate, doneAction: 2);
		output = ((reverb * wet) + (input * dry)) *envGen;
		Out.ar(aux2SendBus, output * aux2Level);


		output = Out.ar(aux1ReturnBus, output);
		output = Out.ar(0, output);
}).add;



SynthDef(\delay,
	ugenGraphFunc: {arg out=0, maxDelayTime=1.0, delayTime=0.4, decayTime = 4.0, wet=1.0, channelBus=0,
aux1SendBus, aux2SendBus, aux1Level=0, aux2Level=0, aux2ReturnBus;
		var dry, input, output, delay;
		dry = 1.0-wet;
		input = In.ar(aux2SendBus, 1);
		delay = CombC.ar(
			in: input,
			maxdelaytime: maxDelayTime,
			delaytime: delayTime,
			decaytime: decayTime)!2;
		output = (delay * wet) + (input * dry);
		Out.ar(aux1SendBus, output * aux1Level);

	    output = Out.ar(aux2ReturnBus, output);
		output = Out.ar(0, output);

}).add;


SynthDef(\masterVolume, { arg volume=1.0;
	var in, out;
	in = In.ar(0, 2);
	out = ReplaceOut.ar(0, in * volume);
}).add;
)
------------------------------------------------------------------------------------------------------------------------------
//aux sends for delay and reverb + control busses
(
~aux1SendBus = Bus.new(
	rate: \audio,
	index: 5,
	numChannels: 1,
	server: s);

~aux2SendBus = Bus.new(
	rate: \audio,
	index: 6,
	numChannels: 1,
	server: s);

~aux1ReturnBus = Bus.new(
	rate: \audio,
	index: 7,
	numChannels: 1,
	server: s);
~aux2ReturnBus = Bus.new(
	rate: \audio,
	index: 8,
	numChannels: 1,
	server: s);

~channelBus=0;
~mixBus=0;

~processors = Group.new(s);
~effects = Group.new(~processors, \addAfter);
~masterVolume = Group.new(~effects, \addAfter);

~listOfSliderControlBusses = List.fill(4, {arg i;
	Bus.control(s, 1);//wet, dry, synth, reverb, delay
});

//~wetBus0
//~dryBus1
//~reverbBus2
//~delayBus3

~listOfDelayControlBusses = List.fill(2, {arg i;
	Bus.control(s,1);
});

//~DTBus0
//~DcTBus1


~listOfReverbControlBusses = List.fill(3, {arg i;
	Bus.control(s,1);
});
//mixBus 0
//roomBus 1
//dampBus 2
)
------------------------------------------------------------------------------------------------------------------------------
//Testing for audio flow
//delete the comment brackets for inputs to simply set and test audio flow without GUI
//must call delay and reverb synths for aux1Level, and aux2Level to work on GUI sliders

/*
//Inputs
~input = Synth(\soundIn, [\channelBus, ~channelBus, \aux1SendBus, ~aux1SendBus, \aux2SendBus, ~aux2SendBus, \aux1Level, 0, \aux2Level, 0], target: ~processors, addAction: \addToHead);


~input2 = Synth(\vocode, [\voiced, 0.9, \channelBus, ~channelBus, \aux1SendBus, ~aux1SendBus, \aux2SendBus, ~aux2SendBus, \aux1Level, 0, \aux2Level, 0], target: ~processors, addAction: \addToTail);
*/
(
//Effects
Synth(\delay, [\maxDelayTime, 1.0, \delayTime, ~listOfDelayControlBusses.at(0).asMap, \decaytime, ~listOfDelayControlBusses.at(1).asMap, \wet, 1, \aux1SendBus,
~aux1SendBus,\aux2SendBus,~aux2SendBus, \aux1Level, 0,\aux2Level, 0, \aux1ReturnBus, ~aux1ReturnBus], ~effects, addAction: \addToHead);

Synth(\reverb, [\aux1SendBus, ~aux1SendBus, \aux2SendBus, ~aux2SendBus, \aux1Level, 0, \aux2Level, 0, \aux2ReturnBus, ~aux2ReturnBus, \mix, ~listOfReverbControlBusses.at(0).asMap, \room, ~listOfReverbControlBusses.at(1).asMap, \damp, ~listOfReverbControlBusses.at(2).asMap], target: ~effects, addAction: \addToHead);

//Volume
~volume = Synth(\masterVolume, [\volume, 1.0], target: ~masterVolume, addAction: \addToHead);

)

/*
~input.set(\aux1Level, 1.0);
~input.set(\aux2Level, 1.0);
~input2.set(\aux1Level, 1.0);
~input2.set(\aux2Level, 1.0);
*/


//s.scope;

------------------------------------------------------------------------------------------------------------------------------
//MIDI and Control Bus Information
(
MIDIClient.init;
MIDIIn.connectAll;

~cubby = List.newClear(128);
~sustainPedalState = 0;
~sustainList = List.new();


MIDIdef.noteOn(
	key: \noteOnEvent,
	func: {arg velocity, noteNumber, channel;
		var freq, synth, vocodeControlBus, reverbControlBus, delayControlBus;
		vocodeControlBus = ~listOfSliderControlBusses.at(0);
		reverbControlBus = ~listOfSliderControlBusses.at(2);
		delayControlBus = ~listOfSliderControlBusses.at(3);


		freq = noteNumber.midicps;

		synth = Synth(\vocode, [\freq, freq, \amp2, vocodeControlBus.asMap, \voiced, 0.9, \channelBus, ~channelBus, \aux1SendBus, ~aux1SendBus, \aux2SendBus, ~aux2SendBus, \aux1Level, reverbControlBus.asMap, \aux2Level, delayControlBus.asMap, \gate, 1], ~processors, addAction: \addToTail);
		~cubby.put(noteNumber, synth);
});


MIDIdef.noteOff(
	key: \noteOffEvent,
	func: { arg velocity, noteNumber, channel;
		var releaseVelocity, synth;
		// releaseVelocity = velocity.linlin(0, 127, 0.0, 1.0);
		synth = ~cubby.at(noteNumber);
		if(~sustainPedalState == 0,
			{synth.set(\gate, 0);},
			{~sustainList.add(synth);});
});



MIDIdef.cc(
	key: \sustainPedalEvent,
	func: { arg value, ccNumber, channel;
		if(value > 64,
			{~sustainPedalState = 1;},
		{~sustainPedalState = 0;
		~sustainList.do({ arg each;
				each.set(\gate, 0);});
			~sustainList.clear})
	},
	ccNum: 64);
)


------------------------------------------------------------------------------------------------------------------------------
//GUI info
(
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//Window
w = Window.new(
	name: "vocodeGUI",
	bounds: Rect(525, 525, 487, 525))
.background_(Color.new(0.17, 0.17, 0.17)) //(0.6, 0.9, 0.8) !!!!!!!!!!!!!!!!!!
.alpha_(1)
.front
.alwaysOnTop_(true);
~flowLayout = FlowLayout(
	bounds: w.view.bounds,
	margin: 10@10,
	gap:10@10
);
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//FlowLayout + text boxes

w.view.decorator = ~flowLayout;

~labels = ["Wet/Vocode", "Dry/Mic", "Reverb", "Delay"];

~textBoxes = List.fill(4, { arg i;
	StaticText.new(
		parent: w,
		bounds: 80@20/*80 wide, 20 tall*/)
	.string_(~labels.at(i))
	.font_("Monaco", 4)
	.align_(\center)
	.background_(Color.new(0.22, 0.35, 0.8))
	.stringColor_(Color.white)
});
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//Control Specs for Sliders and Effect Knobs
~listOfSliderControlSpecs = List.with(
	ControlSpec.new(0.1, 5.0),//wetampBus 0
	ControlSpec.new(0.3, 1.0),//dryampBus 1
	ControlSpec.new(0.0, 1.0),//reverbBus 2
	ControlSpec.new(0.0, 1.0),//delayBus3
);

~listOfDelayControlSpecs = List.with(
	ControlSpec.new(0.1, 1.0),//DelayTime 0
	ControlSpec.new(0.1, 4.0),//DecayTime 1
);

~listOfReverbControlSpecs = List.with(
	ControlSpec.new(0.1, 1.0),//mix 0
	ControlSpec.new(0.1, 1.0),//room size 1
	ControlSpec.new(0.1, 1.0),//damp 2
);


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//SLiders
~flowLayout.nextLine;

~listOfSliders = List.fill(4, {arg i;
	Slider.new(w, 80@200).background_(Color.white);
});

~listOfSliders.do({ arg each, index;
	each.action = {arg view;
		var val, mappedVal, controlBus, controlSpec, numberBox, slider;
		slider = view;
		numberBox = ~listOfNumberBoxes.at(index);
		controlBus = ~listOfSliderControlBusses.at(index);
		controlSpec = ~listOfSliderControlSpecs.at(index);
		val = slider.value;
		mappedVal = controlSpec.map(val);
		numberBox.value = mappedVal;
		controlBus.set(mappedVal);

	}
});

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//Number Boxes
~flowLayout.nextLine;

~listOfNumberBoxes = List.fill(4, { arg i;
	NumberBox.new(w, 80@20).background_(Color.yellow);
});

~listOfNumberBoxes.do({arg each, index;
	each.action = {arg view;
		var numberBox, slider, val, unMappedVal, controlSpec;
		numberBox = view;
		slider = ~listOfSliders.at(index);
		val = numberBox.value;
		controlSpec = ~listOfSliderControlSpecs.at(index);
		unMappedVal = controlSpec.unmap(val);
		slider.valueAction = unMappedVal;
	}
});

~initialValues = List.with(0.1, 0.3, 0.0, 0.0);

//set sliders and call their action with these values

~initialValues.do({arg each, index;
	var slider, controlSpec, unMappedVal;
	slider = ~listOfSliders.at(index);
	controlSpec = ~listOfSliderControlSpecs.at(index);
	unMappedVal = controlSpec.unmap(each);
	slider.valueAction_(unMappedVal);
});
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//Mic Button

~flowLayout.nextLine;

~micButton = Button.new(
	parent: w.view,
		bounds: 220@80);

~micButton.states_([
	["Mic Off", Color.black, Color.new(0.51, 0.51, 0.51)],
	["Mic ON", Color.black, Color.blue]
]);

~micButton.action = {arg view;
	var button, buttonState, wetBus, dryBus, synthBus, reverbBus, delayTimeBus;
	button = view;
	buttonState = button.value;

	if(buttonState == 1,
		{~synth1 = Synth(\soundIn, [\channelBus, ~channelBus, \amp, ~listOfSliderControlBusses.at(1).asMap, \auxLevel1, ~listOfSliderControlBusses.at(2).asMap, \auxLevel2, ~listOfSliderControlBusses.at(3).asMap], target: ~processors, addAction: \addToHead);
		},
		{~synth1.free})
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////freeAll Button
~freeAllButton = Button.new(
	parent: w.view,
	bounds: 220@80);

~freeAllButton.states_([
	["Free all", Color.black, Color.new(0.51, 0.51, 0.51)] //Color.magenta
]);

~freeAllButton.action = {arg view;
	var button, buttonState;
	button = view;
	buttonState = button.value;

	if(buttonState == 1,
		{s.freeAll},
		{s.freeAll})
};

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//Reverb Knobs

~flowLayout.nextLine;

~listOfReverbKnobs = List.fill(3, {arg i;
	Knob.new(w.view, Rect(100, 100, 40, 40));
});

~flowLayout.nextLine;

~reverbLabels = ["Mix", "Room", "Damp"];

~textBoxes = List.fill(3, { arg i;
	StaticText.new(
		parent: w.view,
		bounds: 40@20/*40 wide, 20 tall*/)
	.string_(~reverbLabels.at(i))
	.font_("Monaco", 4)
	.align_(\center)
	.background_(Color.new(0.22, 0.35, 0.8))
	.stringColor_(Color.white)
});


~reverbFunction = {arg val, index;
	var mappedVal;

	mappedVal = ~listOfReverbControlSpecs.map(val);

	~listOfReverbControlBusses.at(index).set(mappedVal);
	{~listOfReverbKnobs.at(index).value_(val)}.defer;
};

~listOfReverbKnobs.do({arg each, index;
	each.action = {arg view;
			var val, mappedVal, controlBus, controlSpec, knobs;
	        knobs = view;
			controlBus = ~listOfReverbControlBusses.at(index);
			controlSpec = ~listOfReverbControlSpecs.at(index);
			val = knobs.value.postln;
			mappedVal = controlSpec.map(val).postln;
			controlBus.set(mappedVal).postln;
		    //~reverbFunction.value(val).postln;

		}
});



//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Delay Knobs

~flowLayout.nextLine;


~listOfDelayKnobs = List.fill(2, {arg i;
	Knob.new(w.view, 40@40);
});

~flowLayout.nextLine;

~delayLabels = ["DT", "DcT"];

~textBoxes = List.fill(2, { arg i;
	StaticText.new(
		parent: w.view,
		bounds: 40@20/*80 wide, 20 tall*/)
	.string_(~delayLabels.at(i))
	.font_("Monaco", 4)
	.align_(\center)
	.background_(Color.new(0.22, 0.35, 0.8))
	.stringColor_(Color.white)
});

~delayFunction = {arg val;
	var mappedVal;

	mappedVal = ~controlSpec.map(val);

	~listOfDelayControlBusses.set(mappedVal);
	{~listOfDelayKnobs.value_(val)}.defer;
};


~listOfDelayKnobs.do({arg each, index;
	each.action = {arg view;
			var val, mappedVal, controlBus, controlSpec, knobs;
			knobs = view;
			controlBus = ~listOfDelayControlBusses.at(index);
			controlSpec = ~listOfDelayControlSpecs.at(index);
			val = knobs.value;
			mappedVal = controlSpec.map(val);
			controlBus.set(mappedVal);
		}
});

)


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
------------------------------------------------------------------------------------------------------------------------------