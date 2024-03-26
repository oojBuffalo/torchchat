# llama-fast
A repo for building and using llama on servers, desktops and mobile

The llama-fast repo enables model inference of llama models (and other LLMs) on servers, desktop and mobile devices.
For a list of devices, see below, under *DEVICES*

# Simple and efficient pytorch-native transformer text generation.

Featuring:

* Very low latency
* <1000 lines of python
* No dependencies other than PyTorch and sentencepiece for server, and Executorch for mobile (plus, your mobile IDE, of course)
* int8/int4 quantization
* Supports Nvidia and AMD GPUs, MPS, CPU (Linux/x86 and MacOS/ARM), xnnpack, and backend-specific mobile runtimes ("delegates").

This is NOT intended to be a "framework" or "library" - it is intended to show off what kind of performance you can get with native PyTorch :) 
Please copy-paste and fork as you desire.

# Supported Models 
The model definition (and much more!) is adopted from gpt-fast, so we support the same models.
See [`gpt-fast` Supported Models](https://github.com/pytorch-labs/gpt-fast?tab=readme-ov-file#supported-models) for a full list.

# Installation
Follow the [`gpt-fast` installation instructions](https://github.com/pytorch-labs/gpt-fast?tab=readme-ov-file#installation).

If you are planning on using mobile backends, you should also install ExecuTorch and any hardware-specific libraries and IDEs.

# A note on tokenizers

There are two different formats for tokenizers, and both are used in this repo.
1 - for generat.py and Python bindings, we use the Google sentencepiece Python operator. This operator consumes a tokenization model in the 'tokenizer.model' format.
2 - for C/C++ inference, we use @Andrej Karpathy's C tokenizer function.  This tokenizer consumes a tokenization model in the 'tokenizer.bin' format.

You can convert tokenizer.model into tokenizer.bin using Andrej's tokenizer.py utility to convert the tokenizer.model to tokenizer.bin format:
```
python tokenizer.py --tokenizer-model=/path/to/tokenizer/tokenizer.model
./run codellama2_7b.bin -z /tokenizer/tokenizer.bin
```

# Generate Text

## Eager Execution

Model definition in model.py, generation code in generate.py.

```
python generate.py --compile --checkpoint_path checkpoints/$MODEL_REPO/model.pth --prompt "Hello, my name is" --device {cuda,cpu,mps}
```
To squeeze out a little bit more performance, you can also compile the prefill with --compile_prefill. This will increase compilation times though.

## AOT Inductor compilation and execution
```
python export.py --checkpoint_path checkpoints/$MODEL_REPO/model.pth --device {cuda,cpu} --out-path ./${MODEL_REPO}.so
```

When you have exported the model, 
Note to self: sopath is missing in the current version. Copy the reported path to ./${MODEL_REPO}.so

```
python generate.py --device {cuda,cpu} --dso ./${MODEL_REPO}.so --prompt "Hello my name is"
```

Note to self: --dso does not currently take an argument, and always loads stories15M.so.

## ExecuTorch mobile compilation

### The basics

Use a small model like stories15M.pt to test the instructions in the following section.

```
python et_export.py --checkpoint_path checkpoints/$MODEL_REPO/model.pth -d fp32 {-xnnpack|-coreml|--mps} --out-path ./${MODEL_REPO}.pte
```

How do run is problematic -- I would love to run it with 
```
python generate.py --pte ./${MODEL_REPO}.pte --prompt "Hello my name is"
```
but *that requires xnnpack to work in python!* 

### Making your models fit and execute fast!

Next, we'll show you how to optimize your model for mobile execution. The basic model build for mobile surfaces two issues:
Models quickly run out of memory and execution can be slow. In this section, we show you how to fit your models in the limited 
memory of a mobile device, and optimize execution speed -- both using quantization. This is the `llama-fast` repo after all!

#### 8 bit integer quantization
The simplest way to quantize is with int8 quantization, where each value is represented by an 8 bit integer, and a 
floating point scale:  
```
python et_export.py --checkpoint_path checkpoints/$MODEL_REPO/model.pth -d fp32 --quant int8 {-xnnpack|-coreml|--mps} --out-path ./${MODEL_REPO}_int8.pte
```

Now you can run your model with the same command as before:
```
python generate.py --ptr ./${MODEL_REPO}_int8.pte --prompt "Hello my name is"
```

#### 4 bit integer quantization (8da4w)
To compress your model even more, 4 bit integer quantization may be used.  To achieve good accuracy, we recommend the use 
of groupwise quantization where (small to mid-sized) groups of int4 weights share a scale.  We also quantize activations to 8 bit, giving 
this scheme its name (8da4w = 8b dynamically quantized activations with 4b weights).
```
python et_export.py --checkpoint_path checkpoints/$MODEL_REPO/model.pth -d fp32 --quant 8da4w {-xnnpack|-coreml|--mps} --out-path ./${MODEL_REPO}_8da4w.pte
```

Now you can run your model with the same command as before:
```
python generate.py --ptr ./${MODEL_REPO}_8da4w.pte --prompt "Hello my name is"
```

#### Quantization with GPTQ (8da4w-gptq)
TBD.


# Standalone Execution 

## Desktop and Server Execution
This has been tested with Linux and x86 (using CPU ~and GPU~), and MacOS and ARM/Apple Silicon.

In addition to running with the generate.py driver in Python, you can also run PyTorch models without the Python runtime, based on Andrej's magnificent llama2.c code.
(Installation instructions courtesy of @Bert Maher's llama2.so)

Build the runner like this
```
cd ./runner-posix
cmake -Bbuild -DCMAKE_PREFIX_PATH=`python3 -c 'import torch;print(torch.utils.cmake_prefix_path)'`
cmake --build build
```

To run, use the following command (assuming you already generated the tokenizer.bin tokenizer model):
```
LD_LIBRARY_PATH=$CONDA_PREFIX/lib ./build/run ../${MODEL_REPO}.so -z ../${MODEL_REPO}.bin
```

## Mobile and Edge Execution
This has been shown to run on x86. with the proper IDE environment, you can compile for your specific target. 
For a GUI integration in iOS and Android, please refer to...

Build the runner like this
```
cd ./runner-mobile
cmake -Bbuild -DCMAKE_PREFIX_PATH=`python3 -c 'import torch;print(torch.utils.cmake_prefix_path)'`
cmake --build build
```

To run your pte model, use the following command (assuming you already generated the tokenizer.bin tokenizer model):
```
./build/run ../${MODEL_REPO}{,_int8,_8da4w}.pte -z ../${MODEL_REPO}.bin
```

