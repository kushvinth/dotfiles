{
  fetchurl,
  fetchzip,
  linkFarm,
}:
# whisper.cpp models for services.local-dictation, pinned by Hugging Face
# revision + hash. whisper.cpp looks for the Core ML encoder by name next to
# the ggml weights (ggml-large-v3-turbo-q5_0.bin ->
# ggml-large-v3-turbo-encoder.mlmodelc) and runs it on the Neural Engine.
let
  whisperRev = "5359861c739e955e79d9a303bcbc70fb988958b1"; # ggerganov/whisper.cpp
  vadRev = "9ffd54a1e1ee413ddf265af9913beaf518d1639b"; # ggml-org/whisper-vad
  hf =
    repo: rev: file:
    "https://huggingface.co/${repo}/resolve/${rev}/${file}";

  coreml = fetchzip {
    name = "ggml-large-v3-turbo-encoder-coreml";
    url = hf "ggerganov/whisper.cpp" whisperRev "ggml-large-v3-turbo-encoder.mlmodelc.zip";
    stripRoot = false;
    postFetch = "rm -rf $out/__MACOSX";
    hash = "sha256-7xhQfcIjGzFTj5fo7/zgkNB7hDXGVgAw4buQy8OsLFE=";
  };
in
linkFarm "whisper-models" {
  "ggml-large-v3-turbo-q5_0.bin" = fetchurl {
    url = hf "ggerganov/whisper.cpp" whisperRev "ggml-large-v3-turbo-q5_0.bin";
    sha256 = "394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2";
  };
  "ggml-large-v3-turbo-encoder.mlmodelc" = "${coreml}/ggml-large-v3-turbo-encoder.mlmodelc";
  "ggml-silero-v6.2.0.bin" = fetchurl {
    url = hf "ggml-org/whisper-vad" vadRev "ggml-silero-v6.2.0.bin";
    sha256 = "2aa269b785eeb53a82983a20501ddf7c1d9c48e33ab63a41391ac6c9f7fb6987";
  };
}
