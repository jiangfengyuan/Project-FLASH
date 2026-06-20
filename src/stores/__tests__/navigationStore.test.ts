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

  it('computes direction based on tab order', () => {
    useNavigationStore.getState().navigateTo('idea');
    expect(useNavigationStore.getState().direction).toBe(1);
    useNavigationStore.getState().navigateTo('log');
    expect(useNavigationStore.getState().direction).toBe(-1);
  });

  it('computes forward direction when entering a non-tab page', () => {
    useNavigationStore.getState().navigateTo('logFlow');
    expect(useNavigationStore.getState().direction).toBe(1);
  });

  it('computes backward direction when leaving a non-tab page', () => {
    useNavigationStore.getState().navigateTo('logFlow');
    useNavigationStore.getState().navigateTo('log');
    expect(useNavigationStore.getState().direction).toBe(-1);
  });
});
