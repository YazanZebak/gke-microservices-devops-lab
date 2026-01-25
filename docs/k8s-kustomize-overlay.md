# Kustomize Overlay Step

## 1. Objectives

- Reduce CPU and memory consumption for services that were bottlenecking the GKE cluster.
- Prevent the default load generator from consuming cluster resources, as it is not needed during normal operations.
- Keep the original base manifests intact to allow future updates without conflicts.

---

## 2. Approach

1. **Do not modify the base**  
   The base manifests from Online Boutique are treated as read-only. Any changes must go in a separate overlay to avoid conflicts with future updates.

2. **Create an overlay folder**  
   A dedicated folder in the project repository contains all modifications. This overlay references the base and applies targeted changes through Kustomize patches.

3. **Targeted resource reduction**  
   Only services identified as CPU-intensive were modified. This avoids unnecessarily reducing resources for services that do not create bottlenecks.

4. **Disabling the load generator**  
   Rather than removing files or editing the base, the load generator is disabled by a patch (setting replicas to 0). This keeps the base intact and allows it to be re-enabled easily later if needed.

5. **Separation of concerns**  
   - Base manifests = original application  
   - Overlay = project-specific modifications  

---

## 3. Reasoning Behind Decisions

- **Safety:** By leaving the base untouched, future updates from the upstream Online Boutique repository can be pulled without overwriting our changes.
- **Clarity:** All project-specific changes are in one overlay folder, making it easy to track, document, and maintain.
- **Scalability:** Patches are applied only to specific services, keeping the cluster optimized while maintaining functionality.
- **Testability:** Disabling the load generator allows us to test the cluster without consuming unnecessary resources, preparing for the next step where the load generator will run externally.
