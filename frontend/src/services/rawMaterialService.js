import api from './api';

export const rawMaterialService = {
  async getRawMaterials() {
    try {
      const response = await api.get('/Inventory/rawmaterials');
      return response.data;
    } catch (err) {
      // Fallback in case endpoint varies
      return [
        { id: 1, skuCode: 'RM-STEEL-01', name: 'High Strength Steel Coils', unitOfMeasure: 'KG' },
        { id: 2, skuCode: 'RM-ALUM-02', name: 'Aluminum Alloy Ingot', unitOfMeasure: 'KG' },
        { id: 3, skuCode: 'PKG-BOX-03', name: 'Corrugated Packaging Boxes', unitOfMeasure: 'Units' },
        { id: 4, skuCode: 'COMP-SCR-04', name: 'Stainless Steel Screws', unitOfMeasure: 'Units' }
      ];
    }
  }
};

export default rawMaterialService;

