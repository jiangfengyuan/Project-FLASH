import { beforeEach, describe, expect, it } from 'vitest';
import { useNavigationStore } from '@/stores/navigationStore';

describe('navigationStore', () => {
  beforeEach(() => {
    localStorage.clear();
    useNavigationStore.setState(useNavigationStore.getInitialState(), true);
  });

  it('navigates to a tab page and updates activeTab', () => {
    useNavigationStore.getState().navigateTo('idea');
    expect(useNavigationStore.getState().currentPage).toBe('idea');
    expect(useNavigationStore.getState().activeTab).toBe('idea');
  });

  it('navigates to a non-tab page without changing activeTab', () => {
    useNavigationStore.getState().navigateTo('logFlow');
    expect(useNavigationStore.getState().currentPage).toBe('logFlow');
    expect(useNavigationStore.getState().activeTab).toBe('log');
  });

  it('sets active tab', () => {
    useNavigationStore.getState().setActiveTab('calendar');
    expect(useNavigationStore.getState().activeTab).toBe('calendar');
    expect(useNavigationStore.getState().currentPage).toBe('calendar');
  });
});
