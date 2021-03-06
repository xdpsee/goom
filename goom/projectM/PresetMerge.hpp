#ifndef PRESET_MERGE_HPP
#define PRESET_MERGE_HPP
#include "Preset.hpp"
#include "Pipeline.hpp"

class PresetMerger
{
public:
  static void MergePresets(PresetOutputs & A,  PresetOutputs & B, float ratio, int gx, int gy);
};

class PipelineMerger
{
 template <class T> inline static T lerp(T a, T b, float ratio)
{
  return a * ratio + b * (1 - ratio);
}

public:
  static void MergePipelines(const Pipeline &a,  const Pipeline &b, Pipeline &out, float ratio);
};

#endif
