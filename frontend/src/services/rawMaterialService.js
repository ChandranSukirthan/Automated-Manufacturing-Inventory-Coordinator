import api from './api';

export const rawMaterialService = {
  async getRawMaterials() {
    const response = await api.get('/Inventory/rawmaterials');
    return response.data;
  }
};

export default rawMaterialService;

