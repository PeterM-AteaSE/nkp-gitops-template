# AI Workload Guide - NVIDIA A30 GPU Infrastructure

> **Note:** This document is a primer and example only. The figures, configurations, and recommendations are illustrative starting points. Actual performance, capacity, and configuration will vary based on your specific workload, model versions, quantization settings, and cluster environment. Validate all settings against your own benchmarks before relying on them in production.

## Hardware Specifications

**Cluster Configuration:**
- Platform: Nutanix
- GPUs: 2x NVIDIA A30
- GPU Memory: 24GB per GPU (48GB total)
- Architecture: Ampere (A100 class, optimized for inference)

## Realistic Capabilities

### ✅ Well-Suited Workloads

#### 1. LLM Inference (Primary Use Case)

**Small to Medium Models (7B-13B parameters):**
- **Excellent performance** with multiple concurrent users
- **Examples:** Llama 3.1 8B, Mistral 7B, Phi-3, CodeLlama 13B
- **Capability:** Run 2-4 models simultaneously across both GPUs
- **Expected Performance:**
  - 8B models: ~40-60 tokens/second per GPU
  - 13B models: ~25-35 tokens/second per GPU

**Larger Models (30B-70B parameters):**
- **Feasible but limited** - requires quantization
- **Examples:** Llama 3.1 70B (4-bit quantized)
- **Capability:** Single model deployment, lower concurrency
- **Expected Performance:**
  - 70B quantized: ~8-15 tokens/second (both GPUs combined)
- **Best for:** Single-user or low-concurrency scenarios

#### 2. Fine-tuning & Training

**Small Models (up to 7B parameters):**
- Full fine-tuning possible with reasonable batch sizes
- Training time: Hours to days depending on dataset size

**Larger Models (13B+ parameters):**
- LoRA/QLoRA fine-tuning only
- Parameter-efficient training methods required

#### 3. Embeddings & RAG (Retrieval-Augmented Generation)

- **Excellent** for embedding generation
- Models: BGE, E5, all-mpnet-base-v2
- Can process thousands of documents efficiently
- Ideal for semantic search and document retrieval systems

### ⚠️ Limitations

#### Cannot Handle

1. **Very large models at full precision:**
   - Models over 180B parameters (e.g., GPT-4 class models)
   - Full precision inference of 70B+ models

2. **High-concurrency production workloads:**
   - Not suitable for 100+ simultaneous users
   - Public-facing services with unpredictable load spikes

3. **Large-scale training:**
   - Multi-day distributed training jobs
   - Training models from scratch (13B+)

#### Performance Considerations

**Context Length Impact:**
- **8K tokens:** Comfortable, good performance
- **32K+ tokens:** Significant memory strain, reduced throughput
- Longer contexts = slower inference and higher memory usage

**Concurrency vs. Throughput:**
- Batch inference more efficient than streaming for multiple users
- Trade-off between response latency and total throughput

**MIG (Multi-Instance GPU) Support:**
- A30 supports MIG partitioning (up to 4 instances per GPU)
- Good for resource isolation between teams/applications
- See configuration in `templates/ollama/values/values.yaml`

## Practical Deployment Recommendations

### Ollama Configuration

For the deployment in this repository, recommended configuration:

```yaml
# templates/ollama/values/values.yaml
ollama:
  gpu:
    enabled: true
    type: 'nvidia'
    number: 2  # Use both A30 GPUs
    
  models:
    # Recommended starter models
    pull:
      - llama3.1:8b      # Fast, versatile, general purpose
      - mistral:7b        # Strong reasoning capabilities
      - codellama:13b     # Code generation and understanding
      - nomic-embed-text  # Embeddings for RAG
    
    # Optional: Pre-load into memory
    run:
      - llama3.1:8b
```

### Expected User Load

**Responsive Experience (< 1 second latency):**
- 10-20 concurrent users with 8B models
- 5-10 concurrent users with 13B models

**Acceptable Experience (2-5 second latency):**
- 30-50 concurrent users with 8B models
- 15-25 concurrent users with 13B models

**Peak Load:**
- Up to 50+ users if acceptable latency increases to 5-10 seconds
- Queue management recommended for burst traffic

### Resource Allocation Strategy

#### Option 1: Shared Pool (Default)
Both GPUs available to all workloads, Kubernetes scheduler manages allocation.

**Pros:**
- Maximum flexibility
- Better resource utilization
- Simple configuration

**Cons:**
- No isolation between teams
- One workload can starve others

#### Option 2: MIG Partitioning
Partition each A30 into smaller instances (e.g., 4x 6GB slices per GPU).

**Pros:**
- Resource isolation
- Guaranteed capacity per team/app
- Better multi-tenancy

**Cons:**
- Reduced flexibility
- Some overhead
- Cannot run large models in single partition

```yaml
# Example MIG configuration
ollama:
  gpu:
    enabled: true
    type: 'nvidia'
    mig:
      enabled: true
      devices:
        1g.6gb: 2  # Allocate 2x small MIG instances
```

#### Option 3: GPU Per Application
Dedicate one GPU per major application/team.

**Pros:**
- Clear resource boundaries
- Predictable performance
- Simple to manage

**Cons:**
- Lower overall utilization
- Less flexibility

## Performance Optimization Tips

### 1. Model Selection
- Start with 7B-8B models for most use cases
- Only scale up if accuracy requirements demand it
- Quantized models (4-bit, 8-bit) save memory with minimal quality loss

### 2. Context Management
- Implement context pruning/summarization
- Keep typical requests under 4K tokens when possible
- Use sliding window for long conversations

### 3. Batching
- Enable dynamic batching in Ollama for multiple concurrent requests
- Batch size of 4-8 optimal for A30

### 4. Caching
- Enable KV-cache for repeated prompts
- Use semantic caching for similar queries

### 5. Monitoring
- Track GPU memory utilization
- Monitor inference latency (p50, p95, p99)
- Set up alerts for GPU temperature and throttling

## Use Case Classification

### ✅ Excellent Fit
- Internal chatbots and assistants
- Code completion and generation (< 100 developers)
- Document Q&A and RAG systems
- Content summarization
- Translation services (internal)
- Prototype and development workloads

### ⚠️ Marginal Fit
- Customer-facing chatbots (limited scale)
- Real-time translation (high volume)
- Multi-modal workloads (image + text)
- Fine-tuning larger models (70B+)

### ❌ Not Suitable
- Public API services with SLA requirements
- Training foundation models
- High-frequency trading signals
- Real-time video processing
- Workloads requiring >48GB GPU memory

## Scaling Considerations

### When to Add More GPUs

**Indicators you need more capacity:**
- Consistent queue depth > 10
- P95 latency > 5 seconds
- GPU utilization > 80% sustained
- User complaints about slow responses
- Cannot fit required models in memory

**Next Steps:**
1. Optimize current deployment first
2. Consider A30 MIG partitioning
3. Add more A30 nodes to cluster
4. Upgrade to H100/A100 for larger models

### Cost-Effective Alternatives

If workload is smaller than expected:
- Share GPUs across multiple Kubernetes namespaces
- Use CPU-only inference for smaller models (< 3B params)
- Time-share GPUs between dev/test environments

## Monitoring and Maintenance

### Key Metrics to Track

```bash
# GPU utilization
nvidia-smi dmon -s u

# Memory usage
nvidia-smi dmon -s m

# Pod GPU allocation
kubectl describe node <node-name> | grep nvidia.com/gpu
```

### Health Checks

**Daily:**
- GPU temperature (should be < 80°C)
- Model load times
- Inference latency

**Weekly:**
- GPU memory fragmentation
- Model cache efficiency
- User satisfaction metrics

**Monthly:**
- Capacity planning review
- Cost per inference analysis
- Model accuracy validation

## Architecture Reference

```
┌─────────────────────────────────────────┐
│         Open WebUI (Frontend)           │
│     (User Interface for Chat/RAG)       │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│          Ollama (Backend)               │
│    - Model Management                   │
│    - Inference Engine                   │
│    - API Gateway                        │
└────────────────┬────────────────────────┘
                 │
         ┌───────┴───────┐
         ▼               ▼
    ┌─────────┐    ┌─────────┐
    │ A30 GPU │    │ A30 GPU │
    │  24GB   │    │  24GB   │
    └─────────┘    └─────────┘
         │               │
         └───────┬───────┘
                 ▼
        Shared Model Storage
         (Persistent Volume)
```

## Related Configuration Files

- Ollama Deployment: `templates/ollama/values/values.yaml`
- Open WebUI: `templates/open-webui/values/values.yaml`
- ArgoCD Apps: `templates/argocd-apps/`

## Summary

**This is a solid mid-tier AI infrastructure** suitable for:
- Internal teams and departmental use cases
- Prototyping and development
- Small to medium-scale production deployments (10-50 users)

**Not suitable for:**
- Large-scale public-facing services
- High-concurrency production (100+ users)
- Training large foundation models

**Best Practice:** Start with conservative model sizes (7B-8B), monitor carefully, and scale up only as needed based on actual usage patterns and performance metrics.

## Change Log

| Date       | Change                                    | Author |
|------------|-------------------------------------------|--------|
| 2026-02-23 | Initial documentation for A30 deployment | -      |
