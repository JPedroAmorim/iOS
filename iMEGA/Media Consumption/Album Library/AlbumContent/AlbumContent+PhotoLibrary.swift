import Foundation
import MEGADomain

extension AlbumContentViewController: PhotoLibraryProvider {
    func hideNavigationEditBarButton(_ hide: Bool) {
        if hide && !shouldUseAlbumContextMenu {
            navigationItem.rightBarButtonItem = nil
        } else {
            configureRightBarButtons()
        }
    }
    
    func showNavigationRightBarButton(_ show: Bool) {
        if show {
            configureRightBarButtons()
        } else {
            navigationItem.rightBarButtonItem = nil
        }
    }
    
    func setupPhotoLibrarySubscriptions() {
        photoLibraryPublisher.subscribeToSelectedPhotosChange { [weak self] in
            self?.selection.setSelectedNodes(Array($0.values))
            self?.didSelectedPhotoCountChange($0.count)
        }
        
        photoLibraryPublisher.subscribeToPhotoSelectionHidden { [weak self] in
            self?.viewModel.dispatch(.configureContextMenu(isSelectHidden: $0))
        }
    }
    
    func didSelectedPhotoCountChange(_ count: Int) {
        updateNavigationTitle(withSelectedPhotoCount: count)
        configureToolbarButtonsWithAlbumType()
    }
}
