%% Active Noise Control with Simulink Real-Time
% Design a real-time active noise control system using a Speedgoat&reg;
% Simulink&reg; Real-Time&trade; target.

% Copyright 2019-2021 The MathWorks, Inc.

%% Active Noise Control (ANC)
% The goal of active noise control is to reduce unwanted sound by producing
% an &ldquo;anti-noise&rdquo; signal that cancels the undesired sound wave.
% This principle has been applied successfully to a wide variety of
% applications, such as noise-cancelling headphones, active sound design in
% car interiors, and noise reduction in ventilation conduits and ventilated
% enclosures.
%
% In this example, we apply the principles of model-based design. First, we
% design the ANC without any hardware by using a simple acoustic model in
% our simulation. Then, we complete our prototype by replacing the
% simulated acoustic path by the <docid:slrealtime_io_ref#bt521yi
% Speedgoat> and its IO104 analog module. The Speedgoat is an external
% Real-Time target for Simulink, which allows us to execute our model in
% real time and observe any data of interest, such as the adaptive filter
% coefficients, in real time.
%
% This example has a companion video: 
% <https://www.mathworks.com/videos/active-noise-control-from-modeling-to-real-time-prototyping-1561451814853.html Active Noise Control &ndash; From Modeling to Real-Time Prototyping>.

%% ANC Feedforward Model
% The following figure illustrates a classic example of _feedforward_ ANC.
% A noise source at the entrance of a duct, such as a fan, is
% &ldquo;cancelled&rdquo; by a loudspeaker. The noise source _b_(_n_) is
% measured with a reference microphone, and the signal present at the
% output of the system is monitored with an error microphone, _e_(_n_).
% Note that the smaller the distance between the reference microphone and
% the loudspeaker, the faster the ANC must be able to compute and play back
% the &ldquo;anti-noise&rdquo;.
% 
% <<../ANC_diagram.png>>
%
% The primary path is the transfer function between the two microphones,
% _W_(_z_) is the adaptive filter computed from the last available error
% signal _e_(_n_), and the secondary path _S_(_z_) is the transfer function
% between the ANC output and the error microphone. The secondary path estimate
% _S'_(_z_) is used to filter the input of the NLMS update function. Also, the
% acoustic feedback _F_(_z_) from the ANC loudspeaker to the reference microphone
% can be estimated (_F'_(_z_)) and removed from the reference signal _b_(_n_).
%
% To implement a successful ANC system, we must estimate both the primary
% and the secondary paths. In this example, we estimate the secondary path
% and the acoustic feedback first and then keep it constant while the ANC
% system adapts the primary path.
%

%% Filtered-X ANC Model
% With Simulink and model-based design, you can start with a basic model of
% the desired system and a simulated environment. Then, you can improve the
% realism of that model or replace the simulated environment by the real
% one. You can also iterate by refining your simulated environment when you
% learn more about the challenges of the real-world system. For example,
% you could add acoustic feedback or measurement noise to the simulated
% environment if those are elements that limit the performance of the
% real-world system.
%
% Start with a model of a Filtered-X NLMS ANC system, including both the
% ANC controller and the duct&rsquo;s acoustic environment. Assume that we
% already have an estimate of the secondary path, since we will design a
% system to measure that later. Simulate the signal at the error microphone
% as the sum of the noise source filtered by the primary acoustic path and
% the ANC output filtered by the secondary acoustic path. Use an &ldquo;LMS
% Update&rdquo; block in a configuration that minimizes the signal captured by
% the error microphone. In a Filtered-X system, the NLMS update&rsquo;s input
% is the noise source filtered by the estimate of the secondary path. To avoid
% an algebraic loop, there is a delay of one sample between the computation
% of the new filter coefficients and their use by the LMS filter.
%
% Set the secondary path to _s_(_n_) = [0.5 0.5 -.3 -.3 -.2 -.2] and the primary
% path to _conv_(_s_(_n_), _f_(_n_)), where _f_(_n_) = [.1 -.1 .2 -.2 .3 -.3 .15 -.15].
% Verify that the adaptive filter properly converges to _f_(_n_), in which case it
% matches the primary path in our model once convolved with the secondary path.
% Note that _s_(_n_) and _f_(_n_) were set arbitrarily, but we could try any
% FIR transfer functions, such as an actual impulse response measurement.
open_system('FilteredX_LMS_ANC')
sim('FilteredX_LMS_ANC')

%% Secondary Path Estimation Model
% Design a model to estimate the secondary path. Use an adaptive filter in
% a configuration appropriate for the identification of an unknown system.
% We can then verify that it converges to f(n).
open_system('SecondaryPath_ANC')
sim('SecondaryPath_ANC')

%% Real-Time Implementation with Speedgoat
% To experiment with ANC in a real-time environment, we built the classic
% duct example. In the following image, from right to left, we have a
% loudspeaker playing the noise source, the reference microphone, the ANC
% loudspeaker, and the error microphone.
% 
% <<../ANC-Duct-Setup.jpg>>
%
% Latency is critical: the system must record the reference microphone,
% compute the response and play it back on the ANC loudspeaker in the time
% it takes for sound to travel between these points. In this example, the
% distance between the reference microphone and the beginning of the
% &ldquo;Y&rdquo; section is 34 cm. The speed of sound is 343 m/s, thus our
% maximum latency is 1 ms, or 8 samples at the 8 kHz sampling rate used in
% this example.
%
% We will be using the Speedgoat real-time target in Simulink, with the
% IO104 analog I/O interface card. The Speedgoat allows us to achieve a
% latency as low as one or two samples.
%
% <<../Speedgoat-Photo.jpg>>
% 
% To realize our real-time model, we use the building blocks that we tested
% earlier, and simply replace the acoustic models by the Speedgoat I/O
% blocks. We also included the measurement of the acoustic feedback from
% the ANC loudspeaker to the reference microphone, and we added some logic
% to automatically measure the secondary path for 10 seconds before
% switching to the actual ANC mode. During the first 10 seconds, white
% noise is played back on the ANC loudspeaker and two NLMS filters are
% enabled, one per microphone. Then, a &ldquo;noise source&rdquo; is played
% back by the model for convenience, but the actual input of the ANC system
% is the reference microphone (this playback could be replaced by a real
% noise source, such as a fan at the right end of the duct). The system
% records the reference microphone, adapts the ANC NLMS filter and
% computes a signal for the ANC loudspeaker. We take care to set up our model
% properties so that the IO104 card is driving the cadence of the Simulink model
% (see <https://www.speedgoat.com/help/slrt/page/io_main/refentry_io104_usage_notes IO104 in interrupt-driven mode>).
% To access the model&rsquo;s folder, open the example by clicking the &ldquo;Open Script&rdquo; button.
% The model&rsquo;s file name is &ldquo;Speedgoat_FXLMS_ANC_model.slx&rdquo;.
%
% <<../Speedgoat-model-screenshot.png>>

%% Noise Reduction Performance
% We have measured the performance of this ANC prototype with both dual
% tones and the actual recording of a muffled washing machine. We obtained
% a noise reduction of 20-30 dB for the dual tones and 8-10 dB for the
% recording, which is a more realistic but also more difficult case. The
% convergence rate for the filter is less than a few seconds with tones,
% but requires much more time for the real case (one or two minutes).
%
% <<../anc_adapted_coefs.png>>

%% Latency Measurements
% Another aspect of performance is the latency of the system, as this
% determines the minimum distance between the reference microphone and the
% ANC loudspeaker. In our prototype, the active ANC loudspeaker that we are
% using may introduce latency, so we can make sure that this is not an
% issue by comparing the response between the two microphones to the
% response between the ANC output signal and the error microphone. The
% difference between these two delays is the maximum time the system has
% available to compute the anti-noise signal from the reference microphone.
% Using the same NLMS identification technique, we obtain the following
% response from the reference microphone to the error microphone:
%
% <<../mic2_to_mic1.png>>
%
% Then, we may compare that response to the secondary path estimation:
%
% <<../mic1_anc.png>>
%
% The difference is only two or three samples, so using our current active
% loudspeaker and the Speedgoat, we cannot significantly reduce the
% distance between the reference microphone and the ANC loudspeaker in our
% prototype. To reduce the distance, we would need a loudspeaker that does
% not introduce any extra latency. We could also increase the sampling rate
% of the Simulink model (the Speedgoat latency is set to one or two samples,
% regardless of the sample rate).
%

%% References
% S. M. Kuo and D. R. Morgan, <https://ieeexplore.ieee.org/document/763310 "Active noise control: a tutorial review,"> in Proceedings of the IEEE, vol. 87, no. 6, pp. 943-973, June 1999.
%
% K.-C. Chen, C.-Y. Chang, and S. M. Kuo, "Active noise control in a duct
% to cancel broadband noise," in IOP Conference Series: Materials Science
% and Engineering, vol. 237, no. 1, 2017. https://iopscience.iop.org/article/10.1088/1757-899X/237/1/012015.
%
% <docid:slrealtime_io_ref#bt521yi Speedgoat real-time target for Simulink>
%
% <https://www.speedgoat.com/help/slrt/page/io_main/refentry_io104_setup Setting up the IO104 module in Simulink>
%
% <https://www.speedgoat.com/help/slrt/page/io_main/refentry_io104_usage_notes Setting up the IO104 in interrupt-driven mode>
%
% See also:
% <docid:audio_ug#mw_482d26e4-6229-4f81-be8b-25474e40ec48 Active Noise Control Using a Filtered-X LMS FIR Adaptive Filter>
%
