% WAVCONV Perform wavelet convolution on LFP data across multiple frequencies
%
%   COEFFMAT = WAVCONV(LFP, WAVFREQS, WAVCYCS, SR) computes the wavelet 
%   convolution of an input local field potential (LFP) signal using a set of
%   Morlet wavelets at specified frequencies.
%
%   Input:
%     LFP       - A vector representing the local field potential signal.
%     WAVFREQS  - A vector of frequencies at which wavelet transforms are applied.
%     WAVCYCS   - Number of cycles for each Morlet wavelet, controlling the 
%                 trade-off between time and frequency resolution.
%     SR        - Sampling rate of the LFP signal in Hz.
%
%   Output:
%     COEFFMAT  - A matrix of wavelet coefficients with dimensions 
%                 [num_freqs x length(LFP)], where each row corresponds 
%                 to the convolution result at a frequency in WAVFREQS.
%
%   The function uses Morlet wavelets, generated by CREATEWAVELET, and
%   performs the convolution in the frequency domain for efficiency using 
%   FFT-based convolution (FCONV).

function coeffmat = wavconv(lfp, wavfreqs, wavcycs, SR)
    % Ensure LFP is a row vector
    lfp = lfp(:).';
    num_freqs = length(wavfreqs);

    % Precompute wavelets for each frequency
    wavcell = cell(num_freqs, 1);
    for f = 1:num_freqs
        wavcell{f} = createWavelet(wavfreqs(f), wavcycs, SR);
    end

    % Initialize the coefficient matrix
    coeffmat = zeros(num_freqs, length(lfp));
    % Perform convolution for each wavelet
    for f = 1:num_freqs
        coeffmat(f,:) = FConv(wavcell{f}, lfp);
    end
end

% CREATEWAVELET Create a Morlet wavelet at a specified frequency and cycle count
%
%   WAVELET = CREATEWAVELET(FREQ, CYCLES, SR) generates a Morlet wavelet 
%   with center frequency FREQ, number of cycles CYCLES, and sampling rate SR.
%
%   This wavelet has a Gaussian envelope and is normalized by L1 norm.
function wavelet = createWavelet(freq, cycles, SR)
    sigma = cycles / (2 * pi * freq);      % Standard deviation of Gaussian
    tbound = ceil(4 * sigma * SR) / SR;    % Time bounds for wavelet
    t = -tbound:1/SR:tbound;
    wavelet = exp(2 * 1i * pi * freq * t) .* exp(-t.^2 / (2 * sigma^2));
    wavelet = wavelet ./ sum(abs(wavelet)); % L1 normalization
end

% FCONV FFT-based convolution of a signal with a kernel
%
%   CONVOLUTION_RESULT_FFT = FCONV(KERNEL, SIGNAL) performs convolution
%   using the FFT, reducing computation time for large signals.
%
%   Input:
%     KERNEL - The convolution kernel (wavelet).
%     SIGNAL - The input signal to convolve with the kernel.
%
%   Output:
%     CONVOLUTION_RESULT_FFT - The convolution result with edge effects removed.
function [convolution_result_fft] = FConv(kernel, signal)
    n_kernel = length(kernel);
    n_signal = length(signal);
    n_convolution = n_kernel + n_signal - 1;
    half_of_kernel_size = (n_kernel - 1) / 2;

    % FFT of kernel and signal
    fft_kernel = fft(kernel, n_convolution);
    fft_signal = fft(signal, n_convolution);
    
    % Inverse FFT of product for convolution result
    convolution_result_fft = ifft(fft_kernel .* fft_signal, n_convolution);

    % Remove edge artifacts
    convolution_result_fft = convolution_result_fft(half_of_kernel_size + 1:end - half_of_kernel_size);
end
