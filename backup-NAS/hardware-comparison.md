# Hardware Comparison: Local AI Server Options

Last updated: 2026-04-03

## Decision: Minisforum MS-S1 Max (128GB)

Selected for: dual 10GbE (NAS), PCIe x16 (future GPU), USB4 V2 (clustering), 2TB NVMe included.

## Comparison Matrix

| Feature | MS-S1 Max | Framework Desktop | CI Companion Core | GMKtec K8 Plus |
|---|---|---|---|---|
| **Price** | **$2,959** | $2,559 ($2,459+SSD) | $3,600 | $399-522 |
| CPU | Ryzen AI Max+ 395 (16C/32T Zen 5) | Same | Same | Ryzen 7 8845HS (8C/16T Zen 4) |
| GPU | Radeon 8060S (40 CU RDNA 3.5) | Same | Same | Radeon 780M (12 CU RDNA 3) |
| RAM | 128GB LPDDR5x-8000 (soldered) | 32/64/128GB (soldered) | 128GB (soldered) | 32GB DDR5-5600 (upgradeable to 96GB) |
| GPU VRAM | Up to 96GB (Win) / 110GB (Linux) | Same | Same | ~8GB shared |
| Memory bandwidth | 256 GB/s | 256 GB/s | 256 GB/s | ~89 GB/s |
| NPU | 50 TOPS (126 total) | 50 TOPS | 50 TOPS | 16 TOPS |
| Storage | 2TB NVMe + 2nd M.2 | BYO (dual M.2) | 2TB NVMe | 1TB NVMe (dual M.2) |
| Ethernet | **Dual 10GbE** | Single 5GbE | Single 5GbE | Dual 2.5GbE |
| USB4 | **V2 (80 Gbps)** x2 | V1 (40 Gbps) x2 | V1 (40 Gbps) x2 | V1 (40 Gbps) x2 |
| PCIe | **x16 half-height** | x4 | None | OCuLink x4 |
| PSU | 320W internal | FlexATX included | 500W | External adapter |
| Rack mount | 2U | No | No | No |
| Dimensions | 222×206×77mm | ~4.5L Mini-ITX | 205×232×90mm | 130×127×48mm |
| Weight | 2.8 kg | ~2 kg | ~4.5 kg | ~0.5 kg |
| Repairability | Medium | Best (modular) | Low (proprietary) | Low (sealed) |
| Cluster support | USB4v2 RPC + 10GbE | Limited | USB4 RPC | No |

## RAM Upgradability

**None of the Strix Halo systems have upgradeable RAM.** LPDDR5x is soldered to the chip package for bandwidth. Must buy 128GB from day one. The GMKtec K8 Plus is the only one with socketed DDR5 (upgradeable to 96GB) but can't run large LLMs.

## 256GB+ Options (If Needed Later)

- **Cluster 2x MS-S1 Max**: ~$6,000 total, 256GB aggregate via USB4v2 RPC, tested at ~11 tok/s on 235B models
- **Mac Studio M4 Ultra**: 192GB unified, ~$5,000+, no PCIe, no 10GbE
- **NVIDIA DGX Spark**: 128GB Grace Blackwell, ~$3,000-5,000 est., not shipping yet
- **Custom 2x RTX 5090**: 64GB VRAM + 256GB system RAM, ~$5,000-8,000

## LLM Benchmarks (Strix Halo 395, 128GB, llama.cpp)

Sources: [Level1Techs](https://forum.level1techs.com/t/strix-halo-ryzen-ai-max-395-llm-benchmark-results/233796), [Framework Community](https://community.frame.work/t/amd-strix-halo-ryzen-ai-max-395-gpu-llm-performance-tests/72521)

| Model | Params | Active | Quant | Gen tok/s | Prompt tok/s | Notes |
|---|---|---|---|---|---|---|
| Qwen 3 30B-A3B (MoE) | 30B | 3B | Q4_K_XL | **72.0** | 604.8 | Sweet spot |
| Llama 2 7B | 7B | 7B | Q4_0 | **47.9** | 998.0 | Blazing |
| Llama 3 8B | 8B | 8B | Q4_K_M | **42.0** | 878.2 | Blazing |
| GPT-OSS 120B | 120B | — | MXFP4 | **46.1** | 775.6 | ROCm optimized |
| dots1 (MoE) | 142B | 14B | Q4_K_XL | **20.6** | 63.1 | Good |
| Llama 4 Scout (MoE) | 109B | 17B | Q4_K_XL | **19.3** | 264.1 | Good |
| Hunyuan-A13B (MoE) | 80B | 13B | Q6_K_XL | **17.1** | 270.5 | Good |
| Mistral Small 3.1 | 24B | 24B | Q4_K_XL | **14.3** | 316.9 | Good |
| Qwen 3 32B | 32B | 32B | Q8_0 | ~10-12 | 226.1 | Usable |
| Llama 3 70B | 70B | 70B | Q4_K_M | **5.0** | 94.7 | Usable for reasoning |

Key: MoE models are the sweet spot (19-72 tok/s). Dense 70B is ~5 tok/s — usable for thinking tasks. ROCm drivers improving ~50% every 3 months.

## Purchase Links

- **MS-S1 Max**: [Amazon ($2,959)](https://www.amazon.com/MINISFORUM-AMD-Ryzen-Max-395/dp/B0G2VJR4JD) | [Minisforum Official](https://store.minisforum.com/products/minisforum-ms-s1-max-mini-pc) | [Price history](https://pricehistory.app/p/minisforum-ms-s1-max-mini-ai-workstation-mlpGYA2h)
- **Framework Desktop**: [frame.work](https://frame.work/desktop)
- **CI Core**: [ci.computer](https://ci.computer/store/p/core)
- **TerraMaster D4-320**: [Amazon ($152)](https://www.amazon.com/TERRAMASTER-D4-320-External-Drive-Enclosure/dp/B0CTTL9R7Z)
- **WD Ultrastar 20TB Renewed**: [Amazon (~$328)](https://www.amazon.com/Western-Digital-Ultrastar-HC560-WUH722020ALE604/dp/B0CV64ZQ38) | [ServerPartDeals](https://serverpartdeals.com)
- **CyberPower UPS**: [Amazon ($220)](https://www.amazon.com/CyberPower-CP1500AVRLCD3-Intelligent-System-Outlets/dp/B0BCMLLSHL)

## Reviews

- [ServeTheHome: MS-S1 Max Review](https://www.servethehome.com/minisforum-ms-s1-max-review-the-best-ryzen-ai-max-mini-pc-yet/)
- [TechRadar: MS-S1 Max Review (4.75/5)](https://www.techradar.com/computing/minisforum-ms-s1-max-mini-pc-review)
- [NotebookCheck: MS-S1 Max Review](https://www.notebookcheck.net/One-of-the-most-powerful-mini-PCs-of-2025-Minisforum-MS-S1-Max-review-AMD-Strix-Halo-Power-128-GB-RAM-Radeon-8060S-for-professionals-AI.1124332.0.html)
- [Framework Desktop review (PCWorld)](https://www.pcworld.com/article/2866400/framework-desktop-review.html)
