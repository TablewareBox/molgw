!=========================================================================
#include "macros.h"
!=========================================================================
subroutine header()
 use m_definitions
 use m_mpi
 use m_warning,only: issue_warning,msg
 implicit none
 integer           :: values(8) 
 character(len=12) :: chartmp
!=====

 WRITE_MASTER(*,'(x,70("="))') 
 WRITE_MASTER(*,'(/,/,12x,a,/,/)') ' Welcome to the fascinating world of MOLGW'
 WRITE_MASTER(*,'(x,70("="))') 
 WRITE_MASTER(*,*)

 call date_and_time(VALUES=values)

 WRITE_MASTER(*,'(a,i2.2,a,i2.2,a,i4.4)') ' Today is ',values(3),'/',values(2),'/',values(1)
 WRITE_MASTER(*,'(a,i2.2,a,i2.2)')        ' It is now ',values(5),':',values(6)
 select case(values(5))
 case(03,04,05,06,07)
   WRITE_MASTER(*,*) 'And it is too early to work. Go back to sleep'
 case(22,23,00,01,02)
   WRITE_MASTER(*,*) 'And it is too late to work. Go to bed and have a sleep'
 case(12,13)
   WRITE_MASTER(*,*) 'Go and get some good food'
 case(17)
   WRITE_MASTER(*,*) 'Dont forget to go and get the kids'
 case default
   WRITE_MASTER(*,*) 'And it is perfect time to work'
 end select


 WRITE_MASTER(*,*) 'Compilation options'
#ifdef HAVE_LIBXC
 call xc_f90_version(values(1),values(2))
 WRITE_ME(chartmp,'(i2,a,i2)') values(1),'.',values(2)
 msg='LIBXC version '//TRIM(chartmp)
 call issue_warning(msg)
#endif
#ifdef CHI0
 msg='CHI0 option has been swichted on at compilation time'
 call issue_warning(msg)
#endif
#ifdef _OPENMP
 write(msg,'(i6)') OMP_get_max_threads()
 msg='OPENMP option is activated with threads number'//msg
 call issue_warning(msg)
#endif
#ifdef LOW_MEMORY2
 msg='LOW_MEMORY version 2 option has been swichted on at compilation time'
 call issue_warning(msg)
#endif
#ifdef LOW_MEMORY3
 msg='LOW_MEMORY version 3 option has been swichted on at compilation time'
 call issue_warning(msg)
#endif
#ifdef CASIDA
 msg='CASIDA option has been swichted on at compilation time'
 call issue_warning(msg)
#endif
#ifdef HAVE_MPI
 msg='Running with MPI'
 call issue_warning(msg)
#endif
#ifdef HAVE_SCALAPACK
 msg='Running with SCALAPACK'
 call issue_warning(msg)
#endif


end subroutine header

!=========================================================================
subroutine dump_out_occupation(title,n,nspin,occupation)
 use m_definitions
 use m_mpi
 implicit none
 character(len=100),intent(in) :: title
 integer,intent(in)            :: n,nspin
 real(dp),intent(in)           :: occupation(n,nspin)
!=====
 integer,parameter :: MAXSIZE=1000
!=====
 integer :: i,ispin
!=====

 WRITE_MASTER(*,'(/,x,a)') TRIM(title)

 if(nspin==2) then
   WRITE_MASTER(*,'(a)') '           spin 1       spin 2 '
 endif
 do i=1,MIN(n,MAXSIZE)
   WRITE_MASTER(*,'(x,i3,2(2(x,f12.5)),2x)') i,occupation(i,:)
 enddo

 WRITE_MASTER(*,*)

end subroutine dump_out_occupation

!=========================================================================
subroutine dump_out_eigenenergy(title,n,nspin,occupation,energy)
 use m_definitions
 use m_mpi
 implicit none
 character(len=100),intent(in) :: title
 integer,intent(in)            :: n,nspin
 real(dp),intent(in)           :: occupation(n,nspin),energy(n,nspin)
!=====
 integer,parameter :: MAXSIZE=300
!=====
 integer  :: i,ispin
 real(dp) :: spin_fact
!=====

 spin_fact = REAL(-nspin+3,dp)

 WRITE_MASTER(*,'(/,x,a)') TRIM(title)

 if(nspin==1) then
   WRITE_MASTER(*,'(a)') '   #       [Ha]         [eV]      '
 else
   WRITE_MASTER(*,'(a)') '   #              [Ha]                      [eV]      '
   WRITE_MASTER(*,'(a)') '           spin 1       spin 2       spin 1       spin 2'
 endif
 do i=1,MIN(n,MAXSIZE)
   WRITE_MASTER(*,'(x,i3,2(2(x,f12.5)),2x)') i,energy(i,:),energy(i,:)*Ha_eV
   if(i<n) then
     if( ANY( occupation(i+1,:) < spin_fact/2.0_dp .AND. occupation(i,:) > spin_fact/2.0 ) ) then 
        if(nspin==1) then
          WRITE_MASTER(*,'(a)') '  -----------------------------'
        else
          WRITE_MASTER(*,'(a)') '  -------------------------------------------------------'
        endif
     endif
   endif
 enddo

 WRITE_MASTER(*,*)

end subroutine dump_out_eigenenergy

!=========================================================================
subroutine dump_out_matrix(print_matrix,title,n,nspin,matrix)
 use m_definitions
 use m_mpi
 implicit none
 logical,intent(in)            :: print_matrix       
 character(len=100),intent(in) :: title
 integer,intent(in)            :: n,nspin
 real(dp),intent(in)           :: matrix(n,n,nspin)
!=====
 integer,parameter :: MAXSIZE=25
!=====
 integer :: i,ispin
!=====

 if( .NOT. print_matrix ) return

 WRITE_MASTER(*,'(/,x,a)') TRIM(title)

 do ispin=1,nspin
   if(nspin==2) then
     WRITE_MASTER(*,'(a,i1)') ' spin polarization # ',ispin
   endif
   do i=1,MIN(n,MAXSIZE)
     WRITE_MASTER(*,'(x,i3,100(x,f12.5))') i,matrix(i,1:MIN(n,MAXSIZE),ispin)
   enddo
   WRITE_MASTER(*,*)
 enddo
 WRITE_MASTER(*,*)

end subroutine dump_out_matrix

!=========================================================================
subroutine output_homolumo(nbf,nspin,occupation,energy,homo,lumo)
 use m_definitions
 use m_mpi
 implicit none
 integer,intent(in)  :: nbf,nspin
 real(dp),intent(in) :: occupation(nbf,nspin),energy(nbf,nspin)
 real(dp),intent(out) :: homo(nspin),lumo(nspin)
 real(dp) :: homo_tmp,lumo_tmp
 integer :: ispin,ibf


 do ispin=1,nspin
   homo_tmp=-1.d+5
   lumo_tmp= 1.d+5
   do ibf=1,nbf
     if(occupation(ibf,ispin)>completely_empty) then
       homo_tmp = MAX( homo_tmp , energy(ibf,ispin) )
     endif

     if(occupation(ibf,ispin)<1.0_dp - completely_empty ) then
       lumo_tmp = MIN( lumo_tmp , energy(ibf,ispin) )
     endif

   enddo
   homo(ispin) = homo_tmp
   lumo(ispin) = lumo_tmp
 enddo


 WRITE_MASTER(*,*)
 WRITE_MASTER(*,'(a,2(3x,f12.6))') ' HOMO energy    [Ha]:',homo(:)
 WRITE_MASTER(*,'(a,2(3x,f12.6))') ' LUMO energy    [Ha]:',lumo(:)
 WRITE_MASTER(*,'(a,2(3x,f12.6))') ' HOMO-LUMO gap  [Ha]:',lumo(:)-homo(:)
 WRITE_MASTER(*,*)


end subroutine output_homolumo



!=========================================================================
subroutine plot_wfn(nspin,basis,c_matrix)
 use m_definitions
 use m_mpi
 use m_atoms
 use m_basis_set
 implicit none
 integer,intent(in)         :: nspin
 type(basis_set),intent(in) :: basis
 real(dp),intent(in)        :: c_matrix(basis%nbf,basis%nbf,nspin)
!=====
 integer,parameter          :: nr=20000
 real(dp),parameter         :: length=10.0_dp
 integer                    :: ir,ibf
 integer                    :: istate1,istate2,istate,ispin
 real(dp)                   :: rr(3)
 real(dp),allocatable       :: phi(:,:),phase(:,:)
 real(dp)                   :: u(3),a(3)
 logical                    :: file_exists
 real(dp)                   :: xmin,xmax
 real(dp)                   :: basis_function_r(basis%nbf)
 integer                    :: ibf_cart,ni_cart,ni,li,i_cart
 real(dp),allocatable       :: basis_function_r_cart(:)
!=====

 WRITE_MASTER(*,*) 
 WRITE_MASTER(*,*) 'Plotting some selected wavefunctions'
 inquire(file='manual_plotwfn',exist=file_exists)
 if(file_exists) then
   open(100,file='manual_plotwfn',status='old')
   read(100,*) istate1,istate2
   read(100,*) u(:)
   read(100,*) a(:)
   close(100)
 else
   istate1=1
   istate2=2
   u(:)=0.0_dp
   u(1)=1.0_dp
   a(:)=0.0_dp
 endif
 u(:) = u(:) / SQRT(SUM(u(:)**2))
 allocate(phase(istate1:istate2,nspin),phi(istate1:istate2,nspin))
 WRITE_MASTER(*,'(a,2(2x,i4))')   ' states:   ',istate1,istate2
 WRITE_MASTER(*,'(a,3(2x,f8.3))') ' direction:',u(:)
 WRITE_MASTER(*,'(a,3(2x,f8.3))') ' origin:   ',a(:)

 xmin = MINVAL( u(1)*x(1,:) + u(2)*x(2,:) + u(3)*x(3,:) ) - length
 xmax = MAXVAL( u(1)*x(1,:) + u(2)*x(2,:) + u(3)*x(3,:) ) + length

 phase(:,:)=1.0_dp

 do ir=1,nr
   rr(:) = ( xmin + (ir-1)*(xmax-xmin)/REAL(nr-1,dp) ) * u(:) + a(:)

   phi(:,:) = 0.0_dp
   
   !
   ! First precalculate all the needed basis function evaluations at point rr
   !
   ibf_cart = 1
   ibf      = 1
   do while(ibf_cart<=basis%nbf_cart)
     li      = basis%bf(ibf_cart)%am
     ni_cart = number_basis_function_am(CARTESIAN,li)
     ni      = number_basis_function_am(basis%gaussian_type,li)

     allocate(basis_function_r_cart(ni_cart))

     do i_cart=1,ni_cart
       basis_function_r_cart(i_cart) = eval_basis_function(basis%bf(ibf_cart+i_cart-1),rr)
     enddo
     basis_function_r(ibf:ibf+ni-1) = MATMUL(  basis_function_r_cart(:) , cart_to_pure(li)%matrix(:,:) )
     deallocate(basis_function_r_cart)

     ibf      = ibf      + ni
     ibf_cart = ibf_cart + ni_cart
   enddo
   !
   ! Precalculation done!
   !

   do ispin=1,nspin
     phi(istate1:istate2,ispin) = MATMUL( basis_function_r(:) , c_matrix(:,istate1:istate2,ispin) )
   enddo

   !
   ! turn the wfns so that they are all positive at a given point
   if(ir==1) then
     do ispin=1,nspin
       do istate=istate1,istate2
         if( phi(istate,ispin) < 0.0_dp ) phase(istate,ispin) = -1.0_dp
       enddo
     enddo
   endif

   WRITE_MASTER(101,'(50(e16.8,2x))') DOT_PRODUCT(rr(:),u(:)),phi(:,:)*phase(:,:)
   WRITE_MASTER(102,'(50(e16.8,2x))') DOT_PRODUCT(rr(:),u(:)),phi(:,:)**2

 enddo

 deallocate(phase,phi)

end subroutine plot_wfn

!=========================================================================
subroutine plot_cube_wfn(nspin,basis,c_matrix)
 use m_definitions
 use m_mpi
 use m_atoms
 use m_basis_set
 implicit none
 integer,intent(in)         :: nspin
 type(basis_set),intent(in) :: basis
 real(dp),intent(in)        :: c_matrix(basis%nbf,basis%nbf,nspin)
!=====
 integer                    :: nx
 integer                    :: ny
 integer                    :: nz
 real(dp),parameter         :: length=4.0_dp
 integer                    :: ir,ibf
 integer                    :: istate1,istate2,istate,ispin
 real(dp)                   :: rr(3)
 real(dp),allocatable       :: phi(:,:),phase(:,:)
 real(dp)                   :: u(3),a(3)
 logical                    :: file_exists
 real(dp)                   :: xmin,xmax,ymin,ymax,zmin,zmax
 real(dp)                   :: basis_function_r(basis%nbf)
 integer                    :: ix,iy,iz,iatom
 integer                    :: ibf_cart,ni_cart,ni,li,i_cart
 real(dp),allocatable       :: basis_function_r_cart(:)
 integer                    :: file_unit
 character(len=200)         :: file_name
!=====

 WRITE_MASTER(*,*) 
 WRITE_MASTER(*,*) 'Plotting some selected wavefunctions in a cube file'
 inquire(file='manual_cubewfn',exist=file_exists)
 if(file_exists) then
   open(100,file='manual_cubewfn',status='old')
   read(100,*) istate1,istate2
   read(100,*) nx,ny,nz
   close(100)
 else
   istate1=1
   istate2=2
   nx=40
   ny=40
   nz=40
 endif
 allocate(phase(istate1:istate2,nspin),phi(istate1:istate2,nspin))
 WRITE_MASTER(*,'(a,2(2x,i4))')   ' states:   ',istate1,istate2

 xmin = MINVAL( x(1,:) ) - length
 xmax = MAXVAL( x(1,:) ) + length
 ymin = MINVAL( x(2,:) ) - length
 ymax = MAXVAL( x(2,:) ) + length
 zmin = MINVAL( x(3,:) ) - length
 zmax = MAXVAL( x(3,:) ) + length

 do istate=istate1,istate2
   do ispin=1,nspin
     file_unit=1000+istate-istate1+(ispin-1)*(istate2-istate1+1)
     WRITE_ME(file_name,'(a,i3.3,a,i1,a)') 'wfn_',istate,'_',ispin,'.cube'
     open(unit=file_unit,file=file_name)
     WRITE_MASTER(file_unit,'(a)') 'cube file generated from MOLGW'
     WRITE_MASTER(file_unit,'(a,i4)') 'wavefunction ',istate1
     WRITE_MASTER(file_unit,'(i6,3(f12.6,2x))') natom,xmin,ymin,zmin
     WRITE_MASTER(file_unit,'(i6,3(f12.6,2x))') nx,(xmax-xmin)/REAL(nx,dp),0.,0.
     WRITE_MASTER(file_unit,'(i6,3(f12.6,2x))') ny,0.,(ymax-ymin)/REAL(ny,dp),0.
     WRITE_MASTER(file_unit,'(i6,3(f12.6,2x))') nz,0.,0.,(zmax-zmin)/REAL(nz,dp)
     do iatom=1,natom
       WRITE_MASTER(file_unit,'(i6,4(2x,f12.6))') NINT(zatom(iatom)),0.0,x(:,iatom)
     enddo
   enddo
 enddo

 phase(:,:)=1.0_dp

 do ix=1,nx
   rr(1) = ( xmin + (ix-1)*(xmax-xmin)/REAL(nx,dp) ) 
   do iy=1,ny
     rr(2) = ( ymin + (iy-1)*(ymax-ymin)/REAL(ny,dp) ) 
     do iz=1,nz
       rr(3) = ( zmin + (iz-1)*(zmax-zmin)/REAL(nz,dp) ) 


       phi(:,:) = 0.0_dp
       
       !
       ! First precalculate all the needed basis function evaluations at point rr
       !
       ibf_cart = 1
       ibf      = 1
       do while(ibf_cart<=basis%nbf_cart)
         li      = basis%bf(ibf_cart)%am
         ni_cart = number_basis_function_am(CARTESIAN,li)
         ni      = number_basis_function_am(basis%gaussian_type,li)
    
         allocate(basis_function_r_cart(ni_cart))
    
         do i_cart=1,ni_cart
           basis_function_r_cart(i_cart) = eval_basis_function(basis%bf(ibf_cart+i_cart-1),rr)
         enddo
         basis_function_r(ibf:ibf+ni-1) = MATMUL(  basis_function_r_cart(:) , cart_to_pure(li)%matrix(:,:) )
         deallocate(basis_function_r_cart)
    
         ibf      = ibf      + ni
         ibf_cart = ibf_cart + ni_cart
       enddo
       !
       ! Precalculation done!
       !

       do ispin=1,nspin
         phi(istate1:istate2,ispin) = MATMUL( basis_function_r(:) , c_matrix(:,istate1:istate2,ispin) )
       enddo

       !
       ! turn the wfns so that they are all positive at a given point
       if(ir==1) then
         do ispin=1,nspin
           do istate=istate1,istate2
             if( phi(istate,ispin) < 0.0_dp ) phase(istate,ispin) = -1.0_dp
           enddo
         enddo
       endif

       do istate=istate1,istate2
         do ispin=1,nspin
           file_unit=1000+istate-istate1+(ispin-1)*(istate2-istate1+1)
           WRITE_MASTER(file_unit,'(50(e16.8,2x))') phi(istate,ispin)*phase(istate,ispin)
         enddo
       enddo

     enddo
   enddo
 enddo

 deallocate(phase,phi)

 do istate=istate1,istate2
   do ispin=1,nspin
     file_unit=1000+istate-istate1+(ispin-1)*(istate2-istate1+1)
     close(file_unit)
   enddo
 enddo

end subroutine plot_cube_wfn


!=========================================================================
subroutine write_energy_qp(nspin,nbf,energy_qp)
 use m_definitions
 use m_mpi
 implicit none

 integer,intent(in)  :: nspin,nbf
 real(dp),intent(in) :: energy_qp(nbf,nspin)
!=====
 integer,parameter :: unit_energy_qp=51
 integer           :: iorbital
!=====

 WRITE_MASTER(*,'(/,a)') ' Writing energy_qp file'
 open(unit_energy_qp,file='energy_qp',form='formatted')
 WRITE_MASTER(unit_energy_qp,*) nspin
 WRITE_MASTER(unit_energy_qp,*) nbf
 do iorbital=1,nbf
   WRITE_MASTER(unit_energy_qp,*) iorbital,energy_qp(iorbital,:)
 enddo

 close(unit_energy_qp)

end subroutine write_energy_qp


!=========================================================================
subroutine read_energy_qp(nspin,nbf,energy_qp,reading_status)
 use m_definitions
 use m_mpi
 use m_warning,only: issue_warning,msg
 implicit none

 integer,intent(in)   :: nspin,nbf
 integer,intent(out)  :: reading_status
 real(dp),intent(out) :: energy_qp(nbf,nspin)
!=====
 integer,parameter :: unit_energy_qp=51
 integer           :: iorbital,jorbital
 integer           :: nspin_read,nbf_read
 logical           :: file_exists
!=====

 WRITE_MASTER(*,'(/,a)') ' Reading energy_qp file'
 inquire(file='energy_qp',exist=file_exists)
 if(file_exists) then
   open(unit_energy_qp,file='energy_qp',form='formatted',status='old')
   read(unit_energy_qp,*) nspin_read
   read(unit_energy_qp,*) nbf_read
   if( nbf_read /= nbf .OR. nspin_read /= nspin ) then
     msg='energy_qp file does not have the correct dimensions'
     call issue_warning(msg)
     reading_status=2
   else
     do iorbital=1,nbf
       read(unit_energy_qp,*) jorbital,energy_qp(iorbital,:)
       ! Scissor operator
       if( jorbital == -1 ) then
         reading_status=-1
         close(unit_energy_qp)
         return
       endif
     enddo
     reading_status=0
   endif
   close(unit_energy_qp)
 else
   reading_status=1
   msg='file energy_qp does not exist'
   call issue_warning(msg)
 endif


end subroutine read_energy_qp


!=========================================================================