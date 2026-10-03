using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace backend.Models
{
    /// <summary>
    /// A production packaging family.  The short code is the first segment of
    /// every SKU belonging to this family (for example, BP-LAM-001).
    /// </summary>
    public class PackagingType
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string ShortCode { get; set; } = string.Empty;
        public bool IsActive { get; set; } = true;

        [JsonIgnore]
        public ICollection<RawMaterial> RawMaterials { get; set; } = new List<RawMaterial>();
    }
}
